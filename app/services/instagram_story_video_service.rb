require "mini_magick"
require "open3"

# Renders an 8-second 1080×1920 Instagram-story MP4: a slow Ken Burns
# zoom over the article image, a gradient + text that fade out to reveal
# a clean photo, and the site logo. Brand palette/logo/domain come from
# Setting via InstagramStoryAssets. Requires ffmpeg (set FFMPEG_PATH or
# have it on PATH).
class InstagramStoryVideoService
  include InstagramStoryAssets

  FPS          = 25
  DURATION     = 8       # seconds
  MAX_ZOOM     = 1.20    # Ken Burns zoom factor

  # Focal-point presets (normalised 0..1) — one is picked at random each
  # render so successive stories drift in slightly different directions.
  FOCAL_X      = [ 0.50, 0.30, 0.70, 0.40, 0.60 ].freeze
  FADE_OUT_AT  = 5.0     # gradient + text start fading out at this second
  FADE_OUT_DUR = 3.0     # fade-out duration (reaches clean image at DURATION)

  # The `drawtext` filter needs an ffmpeg built with libfreetype. Most Linux
  # distro packages include it; Homebrew's plain `ffmpeg` does not, so prefer
  # the `ffmpeg-full` tap when present. Override with FFMPEG_PATH.
  FFMPEG = ENV["FFMPEG_PATH"].presence ||
           [ "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg", "/usr/local/opt/ffmpeg-full/bin/ffmpeg" ].find { |p| File.executable?(p) } ||
           "ffmpeg"

  def initialize(article, setting: Setting.instance, img_x: nil, img_y: nil, img_w: nil, img_h: nil, gradient_opacity: 55)
    @article          = article
    @setting          = setting
    @img_x            = img_x&.to_i
    @img_y            = img_y&.to_i
    @img_w            = img_w&.to_i
    @img_h            = img_h&.to_i
    @gradient_opacity = gradient_opacity.to_i.clamp(0, 100) / 100.0
  end

  # Returns MP4 bytes, or nil if no image source is available.
  def generate
    blob = image_blob
    return nil unless blob

    source        = MiniMagick::Image.read(blob.download)
    still_file    = Tempfile.new([ "story_still", ".png" ])
    gradient_file = Tempfile.new([ "story_grad",  ".png" ])
    out_file      = Tempfile.new([ "story_video", ".mp4" ])
    logo_file     = render_logo_tempfile

    final_w, final_h, pos_x, pos_y = image_placement(source.width, source.height)
    geo = offset_geometry(pos_x, pos_y)

    # 1. Composite still (canvas + positioned image, no text/gradient)
    imagemagick_convert do |c|
      c << "-size" << "#{STORY_WIDTH}x#{STORY_HEIGHT}"
      c << "xc:#{canvas_color}"
      c << "("
      c << source.path
      c.resize "#{final_w}x#{final_h}!"
      c << ")"
      c.geometry geo
      c.composite
      c << still_file.path
    end

    # 2. Gradient overlay image
    imagemagick_convert do |c|
      c << "-size" << "#{STORY_WIDTH}x#{STORY_HEIGHT}"
      c << "gradient:rgba(0,0,0,#{@gradient_opacity})-rgba(0,0,0,0)"
      c << gradient_file.path
    end

    # 3. Build FFmpeg filter graph and run
    filters = build_filter_graph(logo: logo_file.present?)

    args = [
      FFMPEG, "-y",
      "-loop", "1", "-framerate", FPS.to_s, "-i", still_file.path,    # [0:v]
      "-loop", "1", "-framerate", FPS.to_s, "-i", gradient_file.path  # [1:v]
    ]
    args += [ "-loop", "1", "-framerate", FPS.to_s, "-i", logo_file.path ] if logo_file # [2:v]
    args += [
      "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono",                # audio
      "-filter_complex", filters,
      "-map", "[out]",
      "-map", "#{logo_file ? 3 : 2}:a",
      "-t", DURATION.to_s,
      "-c:v", "libx264", "-preset", "fast", "-crf", "23",
      "-c:a", "aac", "-b:a", "128k",
      "-pix_fmt", "yuv420p",
      "-movflags", "+faststart",
      out_file.path
    ]

    _stdout, stderr, status = Open3.capture3(*args)
    raise "FFmpeg failed: #{stderr}" unless status.success?

    out_file.read
  ensure
    source&.destroy!
    [ still_file, gradient_file, out_file, logo_file ].each { |f| f&.close; f&.unlink }
  end

  private

  def build_filter_graph(logo:)
    total_frames = FPS * DURATION
    fx           = FOCAL_X.sample

    # Ken Burns: scale 2× first so zoompan has sub-pixel precision (eliminates
    # jitter). Sine ease-out (fast start, gentle deceleration) for organic feel.
    zoom_expr = "1+#{(MAX_ZOOM - 1.0).round(6)}*sin(PI/2*on/#{total_frames})"
    x_expr    = "max(0,min(iw-iw/zoom,#{fx.round(4)}*iw-iw/zoom/2))"
    y_expr    = "ih*(1-1/zoom)"

    zoompan = "scale=#{STORY_WIDTH * 2}:#{STORY_HEIGHT * 2}," \
      "zoompan=z='#{zoom_expr}':x='#{x_expr}':y='#{y_expr}':" \
      "d=1:s=#{STORY_WIDTH}x#{STORY_HEIGHT}:fps=#{FPS}"

    graph = []
    graph << "[0:v]#{zoompan}[zp]"
    graph << "[1:v]fade=t=out:st=#{FADE_OUT_AT}:d=#{FADE_OUT_DUR}[grad]"
    graph << "[zp][grad]overlay=0:0[base]"

    # Chain drawtext filters (text fades out with the gradient)
    prev  = "base"
    texts = text_layers
    texts.each_with_index do |layer, i|
      curr = i == texts.size - 1 ? "texted" : "t#{i}"
      graph << "[#{prev}]#{layer[:filter]}[#{curr}]"
      prev = curr
    end

    if logo
      logo_x = STORY_WIDTH  - LOGO_SIZE - LOGO_PAD
      logo_y = STORY_HEIGHT - LOGO_SIZE - LOGO_PAD
      graph << "[texted]fade=t=in:st=0:d=0.5[faded]"
      graph << "[faded][2:v]overlay=#{logo_x}:#{logo_y}[out]"
    else
      graph << "[texted]fade=t=in:st=0:d=0.5[out]"
    end

    graph.join(";")
  end

  def text_layers
    layers = []

    layers << { filter: drawtext(font_sans, domain_caption, 36, "0xFFFFFF@0.55", 90, 1800, fade_start: 0) }

    unless category_label.empty?
      layers << { filter: drawtext(font_sans, category_label, 40, "0xFFFFFF@0.70", 90, 1200, fade_start: 0.5) }
    end

    # Title — one drawtext per wrapped line
    wrap(title, 18).split("\n").each_with_index do |line, i|
      layers << { filter: drawtext(font_serif, line, 88, ffmpeg_color(accent_color), 90, 1280 + i * 105, fade_start: 1.0) }
    end

    layers
  end

  # Builds a single drawtext filter string with a fade-in / hold / fade-out
  # alpha envelope matching the gradient.
  def drawtext(fontfile, text, size, color, x, y, fade_start:)
    fi_end = fade_start + 0.5
    fo_end = FADE_OUT_AT + FADE_OUT_DUR

    alpha = if fade_start == 0
      "if(lt(t,#{FADE_OUT_AT}),1,if(lt(t,#{fo_end}),(#{fo_end}-t)/#{FADE_OUT_DUR},0))"
    else
      "if(lt(t,#{fade_start}),0," \
        "if(lt(t,#{fi_end}),(t-#{fade_start})/0.5," \
        "if(lt(t,#{FADE_OUT_AT}),1," \
        "if(lt(t,#{fo_end}),(#{fo_end}-t)/#{FADE_OUT_DUR},0))))"
    end

    "drawtext=fontfile='#{fontfile}':" \
      "text='#{escape_text(text)}':" \
      "fontsize=#{size}:fontcolor=#{color}:" \
      "x=#{x}:y=#{y}:alpha='#{alpha}'"
  end

  def escape_text(text)
    text.gsub("\\", "\\\\\\\\")
        .gsub("'",  "\\'")
        .gsub(":",  "\\:")
  end
end
