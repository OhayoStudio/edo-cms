class Setting < ApplicationRecord
  has_one_attached :logo_light
  has_one_attached :logo_dark
  has_one_attached :favicon
  has_one_attached :og_default_image

  store_accessor :nav_items,    :primary, :footer
  store_accessor :social_links, :twitter, :instagram, :github, :mastodon, :rss
  store_accessor :theme_colors,
    :primary, :primary_dark, :secondary, :accent, :background, :text_primary, :text

  THEME_DEFAULTS = {
    "primary"      => "#704214",
    "primary_dark" => "#52300f",
    "secondary"    => "#A67B5B",
    "accent"       => "#D9C4A6",
    "background"   => "#F9F7F0",
    "text_primary" => "#704214",
    "text"         => "#423525"
  }.freeze

  CACHE_KEY = "setting/instance"

  def self.instance
    Rails.cache.fetch(CACHE_KEY) { first_or_create! }
  end

  after_save  { Rails.cache.delete(CACHE_KEY) }
  after_touch { Rails.cache.delete(CACHE_KEY) }

  def theme_color(name)
    theme_colors.presence&.dig(name.to_s).presence || THEME_DEFAULTS[name.to_s]
  end

  def primary_nav
    Array(nav_items["primary"]).select { |item| item.is_a?(Hash) && item["label"].present? && item["path"].present? }
  end

  def footer_nav
    Array(nav_items["footer"]).select { |item| item.is_a?(Hash) && item["label"].present? && item["path"].present? }
  end
end
