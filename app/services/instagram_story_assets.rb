# Shared brand-agnostic building blocks for the Instagram story generators
# (PNG via InstagramStoryService, MP4 via InstagramStoryVideoService).
#
# Everything brand-specific is read from Setting so each fork's story
# inherits its own palette, logo, and domain caption without editing
# source. Including services must set @article, @setting, and the
# @img_* / @gradient_opacity ivars in their initializer.
module InstagramStoryAssets
  STORY_WIDTH  = 1080
  STORY_HEIGHT = 1920
  LOGO_SIZE    = 160  # px — rendered logo size on the 1080-wide canvas
  LOGO_PAD     = 50   # px from the right and bottom edges

  # First existing path wins, so the same code runs on a macOS dev box
  # and a Linux container. Override either via ENV to use a packaged font.
  FONT_SERIF_CANDIDATES = [
    ENV["STORY_FONT_SERIF"],
    "/System/Library/Fonts/Supplemental/Georgia.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf"
  ].freeze

  FONT_SANS_CANDIDATES = [
    ENV["STORY_FONT_SANS"],
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
  ].freeze

  def font_serif = @font_serif ||= resolve_font(FONT_SERIF_CANDIDATES)
  def font_sans  = @font_sans  ||= resolve_font(FONT_SANS_CANDIDATES)

  # ── Brand (Setting-driven) ──────────────────────────────────────────────

  # Dark story canvas — the theme's body-ink color reads well behind a
  # light photo + gradient.
  def canvas_color = @setting.theme_color("text")

  # Headline + logo accent — the theme's secondary (peach by default).
  def accent_color = @setting.theme_color("secondary")

  # Small caption at the foot of the card. Prefers the public host so the
  # exported image points readers at the live site.
  def domain_caption = (ENV["APPLICATION_HOST"].presence || @setting.site_name).to_s

  # ImageMagick wants #rrggbb; FFmpeg's drawtext wants 0xrrggbb.
  def ffmpeg_color(hex) = hex.to_s.sub(/\A#/, "0x")

  # Rasterizes the site's light logo to a PNG tempfile sized for the
  # canvas, or returns nil when no logo is set or the format can't be
  # rasterized (e.g. SVG without an rsvg delegate). Caller owns cleanup.
  def render_logo_tempfile
    return nil unless @setting.logo_light.attached?

    blob   = @setting.logo_light.blob
    src    = Tempfile.new([ "story_logo_src", File.extname(blob.filename.to_s) ])
    src.binmode
    src.write(blob.download)
    src.flush

    out = Tempfile.new([ "story_logo", ".png" ])
    MiniMagick::Tool::Convert.new do |c|
      c << "-background" << "none"
      c << "-resize"     << "#{LOGO_SIZE}x#{LOGO_SIZE}"
      c << src.path
      c << out.path
    end
    out
  rescue => e
    Rails.logger.warn("[InstagramStory] logo render skipped: #{e.message}")
    nil
  ensure
    src&.close
    src&.unlink
  end

  # ── Article inputs ──────────────────────────────────────────────────────

  def image_blob
    if @article.featured_image.attached?
      @article.featured_image.blob
    else
      @article.content.embeds.find { |e| e.blob.image? }&.blob
    end
  end

  def title          = @article.title.to_s
  def category_label = @article.category&.name.to_s.upcase

  # ── Geometry / text ───────────────────────────────────────────────────────

  # Computes [final_w, final_h, pos_x, pos_y] for the source image. Uses
  # the editor's crop when given, otherwise covers the canvas centred.
  def image_placement(orig_w, orig_h)
    if @img_w && @img_h
      [ @img_w, @img_h, @img_x || 0, @img_y || 0 ]
    else
      cover   = [ STORY_WIDTH.to_f / orig_w, STORY_HEIGHT.to_f / orig_h ].max
      final_w = (orig_w * cover).round
      final_h = (orig_h * cover).round
      [ final_w, final_h, ((STORY_WIDTH - final_w) / 2.0).round, ((STORY_HEIGHT - final_h) / 2.0).round ]
    end
  end

  # ImageMagick geometry string that handles negative offsets correctly.
  def offset_geometry(x, y)
    "#{x >= 0 ? "+#{x}" : x}#{y >= 0 ? "+#{y}" : y}"
  end

  # Word-wrap: pack words into lines ≤ max_chars.
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

  private

  def resolve_font(candidates)
    candidates.compact.find { |path| File.exist?(path) } || candidates.compact.first
  end
end
