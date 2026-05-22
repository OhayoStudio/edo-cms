module SettingsHelper
  # Default keys used when the CMS hasn't been configured yet. Forks can
  # override by editing the Settings → Navigation textareas in /admin.
  DEFAULT_PRIMARY_NAV_KEYS = %w[stories articles videos categories tags about].freeze
  DEFAULT_FOOTER_NAV_KEYS  = %w[about colophon feed].freeze

  # Registry of everything the admin can pick into the header or footer
  # nav. Each entry's label resolves via i18n (so it stays bilingual)
  # and its path uses Rails route helpers (so the active locale prefix
  # flows through automatically).
  #
  # To add a new nav target — including landing-page anchors or
  # external URLs — append an entry here and a matching nav.primary.<key>
  # label to config/locales/shared/nav.<locale>.yml. Examples:
  #   pricing: { label: t("nav.primary.pricing"), path: root_path(anchor: "pricing") }
  #   twitter: { label: "Twitter",                 path: "https://twitter.com/..." }
  def nav_registry
    {
      stories:    { label: t("nav.primary.stories"),    path: stories_path },
      articles:   { label: t("nav.primary.articles"),   path: articles_path },
      videos:     { label: t("nav.primary.videos"),     path: videos_path },
      categories: { label: t("nav.primary.categories"), path: categories_path },
      tags:       { label: t("nav.primary.tags"),       path: tags_path },
      about:      { label: t("nav.primary.about"),      path: about_path },
      colophon:   { label: t("nav.primary.colophon"),   path: colophon_path },
      feed:       { label: t("nav.footer.rss"),         path: feed_path(format: :rss) },
      terms:      { label: t("nav.footer.terms"),       path: terms_path },
      privacy:    { label: t("nav.footer.privacy"),     path: privacy_path }
    }
  end

  def nav_registry_keys
    nav_registry.keys.map(&:to_s)
  end

  def primary_nav_items
    resolve_nav(cms_setting.primary_nav_keys.presence || DEFAULT_PRIMARY_NAV_KEYS)
  end

  def footer_nav_items
    resolve_nav(cms_setting.footer_nav_keys.presence || DEFAULT_FOOTER_NAV_KEYS)
  end

  def resolve_nav(keys)
    keys.filter_map do |key|
      entry = nav_registry[key.to_sym]
      next nil unless entry
      { key: key.to_sym, label: entry[:label], path: entry[:path] }
    end
  end

  # Look up the YAML-only value for a key, bypassing the
  # Setting::OverridesBackend. Used in the admin form to show the
  # baseline value as a placeholder under the editor's input. Falls
  # back to the bare backend if the Chain hasn't been wired yet (e.g.
  # dev server started before the initializer landed).
  def yaml_default_translation(key, locale)
    yaml_backend = I18n.backend.respond_to?(:backends) ? I18n.backend.backends.last : I18n.backend
    parts = key.to_s.split(".")
    yaml_backend.translate(locale.to_sym, parts.last.to_sym, scope: parts[0..-2], default: nil)
  rescue I18n::MissingTranslation
    nil
  end

  def cms_setting
    @_cms_setting ||= Setting.instance
  end

  def cms_color(name)
    cms_setting.theme_color(name)
  end

  def cms_theme_style_tag
    css = Setting::THEME_DEFAULTS.keys.map { |name|
      "--cms-#{name.tr('_', '-')}: #{cms_color(name)};"
    }.join(" ")
    content_tag(:style, ":root { #{css} }".html_safe)
  end

  # Returns true when the Umami snippet should render: feature is enabled,
  # required fields are present, and we're not in the test env. Dev gets
  # the snippet so the local docker-compose stack is testable end-to-end.
  def analytics_enabled?
    return false if Rails.env.test?
    cms_setting.analytics_provider == "umami" &&
      cms_setting.analytics_website_id.present? &&
      cms_setting.analytics_host.present?
  end

  # Pick http for local hosts (so docker-compose Umami works in dev),
  # https for everything else.
  def analytics_script_url
    host = cms_setting.analytics_host
    scheme = host.match?(/\A(localhost|127\.|192\.168\.|10\.)|:\d+\z/) ? "http" : "https"
    "#{scheme}://#{host}/script.js"
  end
end
