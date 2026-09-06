host = ENV["APPLICATION_HOST"].presence || "localhost"
scheme = ENV.fetch("APPLICATION_HOST_SCHEME", "https")

SitemapGenerator::Sitemap.default_host  = "#{scheme}://#{host}"
SitemapGenerator::Sitemap.public_path   = "public/"
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/"

# Public routes live under an optional `(:locale)` scope, so every path
# helper here has TWO dynamic segments (:locale and :id). A positional call
# like `article_path(article)` binds the record to :locale — the first
# segment — and blows up with "missing required keys: [:id]". Controllers
# never hit this because ApplicationController#default_url_options fills in
# :locale, but that's an instance method and the sitemap runs outside any
# request. Pass :id by keyword instead; the omitted :locale leaves the URL
# unscoped, which resolves via I18n.default_locale.
# `include_root: false` because we add "/" explicitly below with its own
# changefreq/priority — leaving the default on emits the root twice.
SitemapGenerator::Sitemap.create(include_root: false) do
  add "/",        changefreq: "daily",   priority: 1.0
  add "/about",   changefreq: "monthly", priority: 0.5
  add "/colophon", changefreq: "monthly", priority: 0.3

  Article.published.find_each do |article|
    add article_path(id: article),
        lastmod:    article.updated_at,
        changefreq: "weekly",
        priority:   0.8
  end

  Video.find_each do |video|
    add video_path(id: video),
        lastmod:    video.updated_at,
        changefreq: "monthly",
        priority:   0.7
  end

  Category.active.find_each do |category|
    add category_path(id: category),
        lastmod:    category.updated_at,
        changefreq: "weekly",
        priority:   0.6
  end

  Tag.find_each do |tag|
    add tag_path(id: tag),
        changefreq: "weekly",
        priority:   0.5
  end

  Author.active.find_each do |author|
    add author_path(id: author),
        lastmod:    author.updated_at,
        changefreq: "monthly",
        priority:   0.5
  end
end
