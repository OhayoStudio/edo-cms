class Setting < ApplicationRecord
  has_one_attached :logo_light
  has_one_attached :logo_dark
  has_one_attached :favicon
  has_one_attached :og_default_image

  store_accessor :nav_items,    :primary, :footer
  store_accessor :social_links, :twitter, :instagram, :github, :mastodon, :rss
  store_accessor :theme_colors,
    :primary, :primary_dark, :secondary, :accent, :background, :text_primary, :text

  # "Pokeibo" calm-morning palette — sage / ink / peach / cream / rule.
  # Editors can override any of these via Settings → Theme colors.
  THEME_DEFAULTS = {
    "primary"      => "#6e8c75",   # sage-deep — headings, CTAs
    "primary_dark" => "#4a4239",   # ink-soft — hover state
    "secondary"    => "#d9a17f",   # peach-deep — secondary accent
    "accent"       => "#e6dccb",   # rule — borders, dividers
    "background"   => "#f5ede0",   # cream — page background
    "text_primary" => "#6e8c75",   # sage-deep — primary text color
    "text"         => "#2b2620"    # ink — body text
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

  # Nav items are stored as arrays of *registry keys* (strings). The
  # renderer (SettingsHelper#nav_registry) maps each key to a translated
  # label + locale-aware path, so editors don't worry about i18n or URL
  # prefixing. Filters non-string entries so any leftover hashes from
  # the previous {label, path} format are silently ignored.
  def primary_nav_keys
    Array(nav_items["primary"]).filter_map { |item| item.is_a?(String) ? item : nil }
  end

  def footer_nav_keys
    Array(nav_items["footer"]).filter_map { |item| item.is_a?(String) ? item : nil }
  end
end
