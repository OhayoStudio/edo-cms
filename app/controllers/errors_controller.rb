# The "not found" page, in the site's layout and the visitor's language.
# config.exceptions_app sends every 404 here: an unknown address, and a record
# that doesn't exist or isn't published (ActiveRecord::RecordNotFound).
# Other errors keep the static pages in public/.
class ErrorsController < ApplicationController
  def not_found
    respond_to do |format|
      format.html { render status: :not_found }
      format.any  { head :not_found }
    end
  end

  private

  # The error request's own path is /404, so take the language from the address
  # the visitor asked for (/ja/...), then fall back to the usual cookie and header.
  def extract_locale
    original = request.env["action_dispatch.original_path"].to_s[%r{\A/([a-z]{2})(?=/|\z)}, 1]
    original&.to_sym.then { |l| I18n.available_locales.include?(l) ? l : super }
  end
end
