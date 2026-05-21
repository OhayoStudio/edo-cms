require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module EdoCms
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])
    config.active_storage.variant_processor = :mini_magick

    # I18n — English primary, Japanese as a working second locale to
    # demonstrate the pattern. Forks can extend with more locales by
    # appending to available_locales here and dropping matching YAML
    # files into config/locales/. Path-segment routing (/en/..., /ja/...)
    # is wired in config/routes.rb; locale detection is in
    # ApplicationController#switch_locale.
    config.i18n.available_locales = [ :en, :ja ]
    config.i18n.default_locale    = :en
    config.i18n.fallbacks         = { ja: [ :en ], en: [ :ja ] }
    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.yml")]

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
