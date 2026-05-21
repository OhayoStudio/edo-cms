class Setting
  # I18n backend that reads editor-supplied translation overrides off the
  # singleton Setting row, then falls through to the regular YAML backend
  # via the chain configured in config/initializers/i18n_cms_overrides.rb.
  #
  # Override shape (stored as JSONB on settings.translation_overrides):
  #   { "ja" => { "nav.primary.about" => "私たちのこと" },
  #     "en" => { "site.tagline" => "..." } }
  #
  # Cache: `Setting.instance` is already Rails.cache-memoized with
  # invalidation in after_save / after_touch, so every t() call reuses
  # the same hash without an extra trip to Postgres.
  class OverridesBackend
    include I18n::Backend::Base

    def lookup(locale, key, scope = [], options = {})
      return nil unless Setting.table_exists?

      separator = options[:separator] || I18n.default_separator
      full_key  = (Array(scope) + Array(key)).join(separator)

      overrides_for(locale)[full_key].presence
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      # During asset precompile / migrations the DB may not be reachable.
      # Let the YAML backend handle the lookup.
      nil
    end

    def available_locales
      I18n.available_locales
    end

    def reload!
      # No-op: we don't keep our own cache; Setting.instance handles it.
    end

    private

    def overrides_for(locale)
      Setting.instance.translation_overrides[locale.to_s] || {}
    end
  end
end
