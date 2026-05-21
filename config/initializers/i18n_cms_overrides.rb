# Chain the CMS-backed override backend in front of Rails' default
# YAML backend. Any key the editor overrides in /admin/settings wins;
# anything not overridden falls through to the YAML files.
#
# Uses `to_prepare` so it's re-attached on each code reload in
# development (the original I18n.backend gets rebuilt then). The
# guard keeps re-attaches idempotent — wrapping the existing backend
# rather than building a fresh Chain each reload, which would lose
# the YAML cache.
Rails.application.config.to_prepare do
  existing = I18n.backend
  already_chained = existing.is_a?(I18n::Backend::Chain) &&
                    existing.backends.first.is_a?(Setting::OverridesBackend)

  unless already_chained
    I18n.backend = I18n::Backend::Chain.new(Setting::OverridesBackend.new, existing)
  end
end
