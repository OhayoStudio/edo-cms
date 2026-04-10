class SitemapRefreshJob < ApplicationJob
  queue_as :default

  def perform
    SitemapGenerator::Sitemap.create(verbose: false)
    GoogleSearchConsoleService.new.submit_sitemap
  rescue => e
    Rails.logger.error "[SitemapRefresh] #{e.class}: #{e.message}"
    raise
  end
end
