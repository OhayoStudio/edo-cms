SitemapGenerator::Sitemap.default_host  = "https://example.com"
SitemapGenerator::Sitemap.public_path   = "public/"
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/"
SitemapGenerator::Sitemap.ping_search_engines = false  # ping deprecated by Google in 2023

SitemapGenerator::Sitemap.create do
  add "/",        changefreq: "daily",   priority: 1.0
  add "/about",   changefreq: "monthly", priority: 0.5
  add "/colophon", changefreq: "monthly", priority: 0.3

  Article.published.find_each do |article|
    add article_path(article),
        lastmod:    article.updated_at,
        changefreq: "weekly",
        priority:   0.8
  end

  Video.find_each do |video|
    add video_path(video),
        lastmod:    video.updated_at,
        changefreq: "monthly",
        priority:   0.7
  end

  Category.active.find_each do |category|
    add category_path(category),
        lastmod:    category.updated_at,
        changefreq: "weekly",
        priority:   0.6
  end

  Tag.find_each do |tag|
    add tag_path(tag),
        changefreq: "weekly",
        priority:   0.5
  end

  Author.active.find_each do |author|
    add author_path(author),
        lastmod:    author.updated_at,
        changefreq: "monthly",
        priority:   0.5
  end
end
