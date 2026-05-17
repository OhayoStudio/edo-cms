class SitemapRefreshJob < ApplicationJob
  queue_as :default

  def perform
    SitemapGenerator::Sitemap.create(verbose: false)
  rescue => e
    Rails.logger.error "[SitemapRefresh] #{e.class}: #{e.message}"
    raise
  end
end
