require "mini_magick"

class InstagramStoryService
  STORY_WIDTH  = 1080
  STORY_HEIGHT = 1920

  # Font paths — override via ENV for non-macOS environments
  FONT_SERIF = ENV.fetch("STORY_FONT_SERIF", "/System/Library/Fonts/Supplemental/Georgia.ttf")
  FONT_SANS  = ENV.fetch("STORY_FONT_SANS",  "/System/Library/Fonts/HelveticaNeue.ttc")

  # img_x/img_y: top-left position of the image in the 1080×1920 space (can be negative)
  # img_w/img_h: rendered size of the image in the 1080×1920 space
  # When nil, defaults to cover+center.
  def initialize(article, img_x: nil, img_y: nil, img_w: nil, img_h: nil)
    @article = article
    @img_x   = img_x&.to_i
    @img_y   = img_y&.to_i
    @img_w   = img_w&.to_i
    @img_h   = img_h&.to_i
  end

  # Returns PNG bytes, or nil if no image source is available.
  def generate
    blob = image_blob
    return nil unless blob

    source   = MiniMagick::Image.read(blob.download)
    out_file = Tempfile.new([ "story", ".png" ])

    orig_w, orig_h = source.width, source.height

    # Compute final image dimensions and position
    if @img_w && @img_h
      final_w = @img_w
      final_h = @img_h
      pos_x   = @img_x || 0
      pos_y   = @img_y || 0
    else
      # Default: cover the canvas, centred
      cover   = [ STORY_WIDTH.to_f / orig_w, STORY_HEIGHT.to_f / orig_h ].max
      final_w = (orig_w * cover).round
      final_h = (orig_h * cover).round
      pos_x   = ((STORY_WIDTH  - final_w) / 2.0).round
      pos_y   = ((STORY_HEIGHT - final_h) / 2.0).round
    end

    geo = offset_geometry(pos_x, pos_y)

    MiniMagick::Tool::Convert.new do |c|
      # 1. Black base canvas
      c << "-size" << "#{STORY_WIDTH}x#{STORY_HEIGHT}"
      c << "canvas:black"

      # 2. Source image, resized and composited at position
      c << "("
      c << source.path
      c.resize "#{final_w}x#{final_h}!"
      c << ")"
      c.geometry geo
      c.composite

      # 3. Gradient overlay (transparent → dark, bottom half)
      c << "("
      c << "-size" << "#{STORY_WIDTH}x#{STORY_HEIGHT}"
      c << "gradient:rgba(0,0,0,0)-rgba(0,0,0,0.88)"
      c << ")"
      c.gravity "South"
      c.composite

      # 4. Text layers
      annotate c, font: FONT_SANS,  size: 40, fill: "rgba(255,255,255,0.7)",  gravity: "SouthWest", x: 90, y: 1680, body: category_label
      annotate c, font: FONT_SERIF, size: 88, fill: "white",                   gravity: "SouthWest", x: 90, y: 640, body: wrap(title, 18)

      unless excerpt.empty?
        annotate c, font: FONT_SANS, size: 46, fill: "rgba(255,255,255,0.85)", gravity: "SouthWest", x: 90, y: 220, body: wrap(excerpt, 36)
      end

      annotate c, font: FONT_SANS, size: 36, fill: "rgba(255,255,255,0.55)", gravity: "SouthWest", x: 90, y: 90, body: "sepiabraun.com"

      c << out_file.path
    end

    out_file.read
  ensure
    source&.destroy!
    out_file&.close
    out_file&.unlink
  end

  private

  def image_blob
    if @article.featured_image.attached?
      @article.featured_image.blob
    else
      @article.content.embeds.find { |e| e.blob.image? }&.blob
    end
  end

  def title          = @article.title.to_s
  def excerpt        = (@article.excerpt.presence || @article.subtitle.presence).to_s
  def category_label = @article.category&.name.to_s.upcase

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

  def annotate(c, font:, size:, fill:, gravity:, x:, y:, body:)
    return if body.to_s.strip.empty?
    c.font      font
    c.pointsize size.to_s
    c.fill      fill
    c.gravity   gravity
    c.annotate  "+#{x}+#{y}", body
  end
end
