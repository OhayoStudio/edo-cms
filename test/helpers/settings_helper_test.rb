require "test_helper"

class SettingsHelperTest < ActionView::TestCase
  setup do
    @setting = Setting.instance
  end

  def set_social(links)
    @setting.update!(social_links: links)
    @_cms_setting = nil # bust the helper's per-request memoization
  end

  test "skips blank and missing values" do
    set_social("twitter" => "ohayo", "instagram" => "", "github" => nil)

    keys = social_links.map { |l| l[:key] }
    assert_equal [ :twitter ], keys
  end

  test "expands a bare handle against the service base url" do
    set_social("twitter" => "ohayo")

    link = social_links.find { |l| l[:key] == :twitter }
    assert_equal "https://x.com/ohayo", link[:url]
    assert_equal "X / Twitter", link[:label]
  end

  test "strips a leading @ from handles" do
    set_social("instagram" => "@ohayo")

    link = social_links.find { |l| l[:key] == :instagram }
    assert_equal "https://instagram.com/ohayo", link[:url]
  end

  test "passes a full url through untouched" do
    set_social("github" => "https://github.com/OhayoStudio")

    link = social_links.find { |l| l[:key] == :github }
    assert_equal "https://github.com/OhayoStudio", link[:url]
  end

  test "rss resolves to the local feed path" do
    set_social("rss" => "on")

    link = social_links.find { |l| l[:key] == :rss }
    assert_equal feed_path(format: :rss), link[:url]
  end

  test "preserves service display order" do
    set_social("rss" => "on", "twitter" => "ohayo", "github" => "OhayoStudio")

    assert_equal [ :twitter, :github, :rss ], social_links.map { |l| l[:key] }
  end
end
