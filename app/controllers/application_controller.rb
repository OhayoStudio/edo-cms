class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from ActiveRecord::RecordNotFound, with: -> { redirect_to root_path }

  around_action :switch_locale

  # Carry the active locale through every path helper so `<%= articles_path %>`
  # in a view renders `/ja/articles` or `/en/articles` automatically.
  def default_url_options
    { locale: I18n.locale }
  end

  private

  # Resolution order: explicit URL param → persisted cookie →
  # Accept-Language header → default. The first URL hit with /<locale>/
  # wins and persists so subsequent visits land in the same language.
  def switch_locale(&)
    locale = extract_locale
    cookies.permanent[:locale] = locale if params[:locale].present?
    I18n.with_locale(locale, &)
  end

  def extract_locale
    requested = params[:locale].presence || cookies[:locale].presence || browser_locale
    requested&.to_sym.then { |l| I18n.available_locales.include?(l) ? l : I18n.default_locale }
  end

  def browser_locale
    request.env["HTTP_ACCEPT_LANGUAGE"]&.scan(/^[a-z]{2}/)&.first
  end
end
