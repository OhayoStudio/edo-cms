require "mini_magick"

# Renders a 1080×1920 Instagram-story PNG for an article: the article's
# image (cropped/positioned by the editor), a bottom gradient, the title,
# category, site domain, and logo. Brand palette/logo/domain come from
# Setting via InstagramStoryAssets.
class InstagramStoryService
  include InstagramStoryAssets

  # img_x/img_y: top-left of the image in the 1080×1920 space (can be negative)
  # img_w/img_h: rendered size of the image in that space
  # When nil, defaults to cover + centre.
  def initialize(article, setting: Setting.instance, img_x: nil, img_y: nil, img_w: nil, img_h: nil, gradient_opacity: 55)
    @article          = article
    @setting          = setting
    @img_x            = img_x&.to_i
    @img_y            = img_y&.to_i
    @img_w            = img_w&.to_i
    @img_h            = img_h&.to_i
    @gradient_opacity = gradient_opacity.to_i.clamp(0, 100) / 100.0
  end

  # Returns PNG bytes, or nil if no image source is available.
  def generate
    blob = image_blob
    return nil unless blob

    source    = MiniMagick::Image.read(blob.download)
    out_file  = Tempfile.new([ "story", ".png" ])
    logo_file = render_logo_tempfile

    final_w, final_h, pos_x, pos_y = image_placement(source.width, source.height)
    geo = offset_geometry(pos_x, pos_y)

    imagemagick_convert do |c|
      # 1. Base canvas
      c << "-size" << "#{STORY_WIDTH}x#{STORY_HEIGHT}"
      c << "xc:#{canvas_color}"

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
      c << "gradient:rgba(0,0,0,0)-rgba(0,0,0,#{@gradient_opacity})"
      c << ")"
      c.gravity "South"
      c.composite

      # 4. Text layers
      annotate c, font: font_sans,  size: 40, fill: "rgba(255,255,255,0.7)",  gravity: "SouthWest", x: 90, y: 1680, body: category_label
      annotate c, font: font_serif, size: 88, fill: accent_color,             gravity: "SouthWest", x: 90, y: 480,  body: wrap(title, 18)
      annotate c, font: font_sans,  size: 36, fill: "rgba(255,255,255,0.55)", gravity: "SouthWest", x: 90, y: 90,   body: domain_caption

      # 5. Logo — bottom-right (skipped when no logo is configured)
      if logo_file
        logo_x = STORY_WIDTH  - LOGO_SIZE - LOGO_PAD
        logo_y = STORY_HEIGHT - LOGO_SIZE - LOGO_PAD
        c << "("
        c << logo_file.path
        c << ")"
        c.gravity "NorthWest"
        c.geometry "+#{logo_x}+#{logo_y}"
        c.composite
      end

      c << out_file.path
    end

    out_file.read
  ensure
    source&.destroy!
    [ out_file, logo_file ].each { |f| f&.close; f&.unlink }
  end

  private

  def annotate(c, font:, size:, fill:, gravity:, x:, y:, body:)
    return if body.to_s.strip.empty?
    c.font      font
    c.pointsize size.to_s
    c.fill      fill
    c.gravity   gravity
    c.annotate  "+#{x}+#{y}", body
  end
end
