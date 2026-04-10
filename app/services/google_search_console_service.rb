require "googleauth"
require "google/apis/webmasters_v3"

class GoogleSearchConsoleService
  SITE_URL    = "https://sepiabraun.com/"
  SITEMAP_URL = "https://sepiabraun.com/sitemaps/sitemap.xml.gz"
  SCOPE       = "https://www.googleapis.com/auth/webmasters"

  def submit_sitemap
    service               = Google::Apis::WebmastersV3::WebmastersService.new
    service.authorization = credentials
    service.submit_sitemap(SITE_URL, SITEMAP_URL)
    Rails.logger.info "[SearchConsole] Sitemap submitted: #{SITEMAP_URL}"
  end

  private

  def credentials
    json = Base64.decode64(ENV.fetch("GOOGLE_SERVICE_ACCOUNT_JSON"))
    Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(json),
      scope:       SCOPE
    ).tap(&:fetch_access_token!)
  end
end
