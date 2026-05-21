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

  # i18n keys editors can override from /admin/settings → Translations.
  # Anything outside this list is silently dropped by the writer below.
  # Extend in your fork to expose more keys (e.g. landing-page eyebrows)
  # — but keep `_html` keys and large copy blocks OUT; editors typing
  # raw markup is a footgun, and the form scales poorly past ~30 rows.
  EDITABLE_TRANSLATION_KEYS = %w[
    nav.primary.stories
    nav.primary.articles
    nav.primary.videos
    nav.primary.categories
    nav.primary.tags
    nav.primary.about
    nav.primary.colophon
    nav.footer.rss
  ].freeze

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

  # Reader used by Setting::OverridesBackend AND the admin form. Defaults
  # to an empty hash so callers never have to nil-check.
  def translation_overrides
    self[:translation_overrides] || {}
  end

  # Drop anything not in the whitelist and any blank values so the JSON
  # column stays clean. Called from the admin controller.
  def translation_overrides=(value)
    cleaned = (value || {}).each_with_object({}) do |(locale, keys), acc|
      locale_str = locale.to_s
      next unless I18n.available_locales.map(&:to_s).include?(locale_str)

      filtered = (keys || {}).each_with_object({}) do |(k, v), inner|
        next unless EDITABLE_TRANSLATION_KEYS.include?(k.to_s)
        next if v.to_s.strip.blank?
        inner[k.to_s] = v.to_s.strip
      end
      acc[locale_str] = filtered if filtered.any?
    end
    self[:translation_overrides] = cleaned
  end
end
