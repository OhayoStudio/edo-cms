require "test_helper"
require "sitemap_generator"

# Public routes are wrapped in `scope "(:locale)"`, which gives every path
# helper two dynamic segments. config/sitemap.rb runs outside a request, so
# ApplicationController#default_url_options never fills in :locale — a
# positional `article_path(article)` there binds the record to :locale and
# raises. These tests pin the behaviour the sitemap config depends on.
class SitemapGenerationTest < ActionDispatch::IntegrationTest
  include Rails.application.routes.url_helpers

  test "record path helpers resolve without a request-supplied locale" do
    assert_equal "/articles/#{articles(:article_published_tech).to_param}", article_path(id: articles(:article_published_tech))
    assert_equal "/videos/#{videos(:video_intro_rails).to_param}",     video_path(id: videos(:video_intro_rails))
    assert_equal "/categories/#{categories(:category_technology).to_param}", category_path(id: categories(:category_technology))
    assert_equal "/tags/#{tags(:tag_ruby).to_param}",         tag_path(id: tags(:tag_ruby))
    assert_equal "/authors/#{authors(:author_jane).to_param}",   author_path(id: authors(:author_jane))
  end

  test "positional path helpers are ambiguous under the locale scope" do
    # Guards the trap: if this ever stops raising, the (:locale) scope has
    # changed and config/sitemap.rb can go back to the positional form.
    assert_raises(ActionController::UrlGenerationError) do
      article_path(articles(:article_published_tech))
    end
  end

  test "config/sitemap.rb builds a valid sitemap" do
    Dir.mktmpdir do |dir|
      SitemapGenerator::Sitemap.default_host   = "https://example.com"
      SitemapGenerator::Sitemap.public_path    = dir
      SitemapGenerator::Sitemap.sitemaps_path  = nil
      SitemapGenerator::Sitemap.compress       = false
      SitemapGenerator::Sitemap.verbose        = false
      SitemapGenerator::Sitemap.create(include_root: false) do
        add "/", changefreq: "daily", priority: 1.0
        Article.published.find_each { |a| add article_path(id: a), lastmod: a.updated_at }
        Video.find_each             { |v| add video_path(id: v),   lastmod: v.updated_at }
        Category.active.find_each   { |c| add category_path(id: c), lastmod: c.updated_at }
        Tag.find_each               { |t| add tag_path(id: t) }
        Author.active.find_each     { |a| add author_path(id: a),  lastmod: a.updated_at }
      end

      xml  = File.read(File.join(dir, "sitemap.xml"))
      locs = xml.scan(%r{<loc>([^<]+)</loc>}).flatten

      assert_includes locs, "https://example.com"
      assert_includes locs, "https://example.com/articles/#{articles(:article_published_tech).to_param}"
      assert_equal locs.uniq, locs, "sitemap must not contain duplicate <loc> entries"
      assert locs.all? { |l| l.start_with?("https://example.com") }, "all URLs must be absolute"
    end
  end
end
