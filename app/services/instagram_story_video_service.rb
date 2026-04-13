require "mini_magick"
require "open3"

class InstagramStoryVideoService
  STORY_WIDTH  = 1080
  STORY_HEIGHT = 1920
  FPS          = 25
  DURATION     = 8       # seconds
  MAX_ZOOM     = 1.20    # Ken Burns zoom factor

  # Focal-point presets (normalised 0..1) — one is picked at random each render.
  # Slight offsets from centre give a gentle directional drift without being distracting.
  FOCAL_POINTS = [
    [ 0.50, 0.50 ],  # pure centre
    [ 0.40, 0.40 ],  # drift toward top-left
    [ 0.60, 0.40 ],  # drift toward top-right
    [ 0.40, 0.60 ],  # drift toward bottom-left
    [ 0.60, 0.60 ]   # drift toward bottom-right
  ].freeze
  FADE_OUT_AT  = 5.0     # gradient + text start fading out at this second
  FADE_OUT_DUR = 3.0     # fade-out duration (reaches clean image at DURATION)

  LOGO_SVG  = Rails.root.join("app/assets/images/sepia-clear.svg").freeze
  LOGO_SIZE = 160  # px — rendered size on the 1080-wide canvas
  LOGO_PAD  = 50   # px from right and bottom edges

  FFMPEG     = ENV.fetch("FFMPEG_PATH", "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg")
  FONT_SERIF = ENV.fetch("STORY_FONT_SERIF", "/System/Library/Fonts/Supplemental/Georgia.ttf")
  FONT_SANS  = ENV.fetch("STORY_FONT_SANS",  "/System/Library/Fonts/HelveticaNeue.ttc")

  def initialize(article, img_x: nil, img_y: nil, img_w: nil, img_h: nil)
    @article = article
    @img_x   = img_x&.to_i
    @img_y   = img_y&.to_i
    @img_w   = img_w&.to_i
    @img_h   = img_h&.to_i
  end

  # Returns MP4 bytes, or nil if no image source is available.
  def generate
    blob = image_blob
    return nil unless blob

    source        = MiniMagick::Image.read(blob.download)
    still_file    = Tempfile.new([ "story_still", ".png" ])
    gradient_file = Tempfile.new([ "story_grad",  ".png" ])
    logo_file     = Tempfile.new([ "story_logo",  ".png" ])
    out_file      = Tempfile.new([ "story_video", ".mp4" ])

    orig_w, orig_h = source.width, source.height

    # Compute image position/size
    if @img_w && @img_h
      final_w, final_h = @img_w, @img_h
      pos_x, pos_y     = @img_x || 0, @img_y || 0
    else
      cover   = [ STORY_WIDTH.to_f / orig_w, STORY_HEIGHT.to_f / orig_h ].max
      final_w = (orig_w * cover).round
      final_h = (orig_h * cover).round
      pos_x   = ((STORY_WIDTH  - final_w) / 2.0).round
      pos_y   = ((STORY_HEIGHT - final_h) / 2.0).round
    end

    geo = offset_geometry(pos_x, pos_y)

    # 1. Composite still (black canvas + positioned image, no text/gradient)
    MiniMagick::Tool::Convert.new do |c|
      c << "-size" << "#{STORY_WIDTH}x#{STORY_HEIGHT}"
      c << "xc:#423525"
      c << "("
      c << source.path
      c.resize "#{final_w}x#{final_h}!"
      c << ")"
      c.geometry geo
      c.composite
      c << still_file.path
    end

    # 2. Gradient overlay image
    MiniMagick::Tool::Convert.new do |c|
      c << "-size" << "#{STORY_WIDTH}x#{STORY_HEIGHT}"
      c << "gradient:rgba(0,0,0,0.88)-rgba(0,0,0,0)"
      c << gradient_file.path
    end

    # 3. Rasterize logo SVG
    MiniMagick::Tool::Convert.new do |c|
      c << "-background" << "none"
      c << "-resize"     << "#{LOGO_SIZE}x#{LOGO_SIZE}"
      c << LOGO_SVG.to_s
      c << logo_file.path
    end

    # 4. Build FFmpeg filter graph and run
    filters = build_filter_graph

    args = [
      FFMPEG, "-y",
      "-loop", "1", "-framerate", FPS.to_s, "-i", still_file.path,    # [0:v]
      "-loop", "1", "-framerate", FPS.to_s, "-i", gradient_file.path, # [1:v]
      "-loop", "1", "-framerate", FPS.to_s, "-i", logo_file.path,     # [2:v]
      "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono",                # [3:a]
      "-filter_complex", filters,
      "-map", "[out]",
      "-map", "3:a",
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
    [ still_file, gradient_file, logo_file, out_file ].each { |f| f&.close; f&.unlink }
  end

  private

  def build_filter_graph
    total_frames = FPS * DURATION

    # Pick a random focal point for directional drift
    fx, fy = FOCAL_POINTS.sample

    # Ken Burns: scale 2× first so zoompan has sub-pixel precision (eliminates jitter).
    # Sine ease-out (fast start, gentle deceleration) for a more organic feel.
    # Focal point clamped so the crop window never exceeds the 2× canvas.
    zoom_expr = "1+#{(MAX_ZOOM - 1.0).round(6)}*sin(PI/2*on/#{total_frames})"
    x_expr    = "max(0,min(iw-iw/zoom,#{fx.round(4)}*iw-iw/zoom/2))"
    y_expr    = "max(0,min(ih-ih/zoom,#{fy.round(4)}*ih-ih/zoom/2))"

    zoompan = "scale=#{STORY_WIDTH * 2}:#{STORY_HEIGHT * 2}," \
      "zoompan=z='#{zoom_expr}':x='#{x_expr}':y='#{y_expr}':" \
      "d=1:s=#{STORY_WIDTH}x#{STORY_HEIGHT}:fps=#{FPS}"

    # Gradient fades out over the last FADE_OUT_DUR seconds → clean image at end
    graph = []
    graph << "[0:v]#{zoompan}[zp]"
    graph << "[1:v]fade=t=out:st=#{FADE_OUT_AT}:d=#{FADE_OUT_DUR}[grad]"
    graph << "[zp][grad]overlay=0:0[base]"

    # Chain drawtext filters (text also fades out with the gradient)
    prev  = "base"
    texts = text_layers
    texts.each_with_index do |layer, i|
      curr = i == texts.size - 1 ? "texted" : "t#{i}"
      graph << "[#{prev}]#{layer[:filter]}[#{curr}]"
      prev = curr
    end

    # Fade in, then overlay logo at bottom-right
    logo_x = STORY_WIDTH  - LOGO_SIZE - LOGO_PAD
    logo_y = STORY_HEIGHT - LOGO_SIZE - LOGO_PAD
    graph << "[texted]fade=t=in:st=0:d=0.5[faded]"
    graph << "[faded][2:v]overlay=#{logo_x}:#{logo_y}[out]"

    graph.join(";")
  end

  def text_layers
    layers = []

    # Domain (always visible)
    layers << {
      filter: drawtext(FONT_SANS, "sepiabraun.com", 36, "0xFFFFFF@0.55", 90, 1800, fade_start: 0)
    }

    # Category
    unless category_label.empty?
      layers << {
        filter: drawtext(FONT_SANS, category_label, 40, "0xFFFFFF@0.70", 90, 1200, fade_start: 0.5)
      }
    end

    # Title — one drawtext per wrapped line
    wrap(title, 18).split("\n").each_with_index do |line, i|
      layers << {
        filter: drawtext(FONT_SERIF, line, 88, "0xD9C4A6", 90, 1280 + i * 105, fade_start: 1.0)
      }
    end

    # Excerpt
    # unless excerpt.empty?
    #   wrap(excerpt, 36).split("\n").each_with_index do |line, i|
    #     layers << {
    #       filter: drawtext(FONT_SANS, line, 46, "0xFFFFFF@0.85", 90, 1560 + i * 56, fade_start: 1.5)
    #     }
    #   end
    # end

    layers
  end

  # Builds a single drawtext filter string.
  def drawtext(fontfile, text, size, color, x, y, fade_start:)
    fi_end = fade_start + 0.5
    fo_end = FADE_OUT_AT + FADE_OUT_DUR

    # Fade in, hold, then fade out with the gradient
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

  def offset_geometry(x, y)
    "#{x >= 0 ? "+#{x}" : x}#{y >= 0 ? "+#{y}" : y}"
  end

  def image_blob
    if @article.featured_image.attached?
      @article.featured_image.blob
    else
      @article.content.embeds.find { |e| e.blob.image? }&.blob
    end
  end

  def title          = @article.title.to_s
  # def excerpt        = (@article.excerpt.presence || @article.subtitle.presence).to_s
  def category_label = @article.category&.name.to_s.upcase

  def wrap(text, max_chars)
    words = text.split(" ")
    lines = []
    line  = ""
    words.each do |word|
      candidate = line.empty? ? word : "#{line} #{word}"
      if candidate.length <= max_chars
        line = candidate
      else
        lines << line unless line.empty?
        line = word
      end
    end
    lines << line unless line.empty?
    lines.join("\n")
  end
end
