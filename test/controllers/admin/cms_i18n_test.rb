require "test_helper"

# Smoke-tests that the CMS admin pages render in both locales.
class Admin::CmsI18nTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "cms@example.com",
                         password: "password123", password_confirmation: "password123")
    post session_path, params: { email_address: @user.email_address, password: "password123" }
  end

  test "categories + tags index render (en)" do
    get admin_categories_path
    assert_response :success
    assert_match "New Category", response.body
    get admin_tags_path
    assert_response :success
    assert_match "New Tag", response.body
  end

  test "categories + tags render in Japanese" do
    get admin_categories_path(locale: "ja")
    assert_response :success
    assert_match "新規カテゴリー", response.body        # New Category
    assert_match "カテゴリー", response.body            # nav/title
    get new_admin_tag_path(locale: "ja")
    assert_response :success
    assert_match "新規タグ", response.body              # New Tag
  end

  test "authors + videos + articles index render in Japanese" do
    get admin_authors_path(locale: "ja")
    assert_response :success
    assert_match "新規著者", response.body              # New Author
    get admin_videos_path(locale: "ja")
    assert_response :success
    assert_match "新規動画", response.body              # New Video
    get admin_articles_path(locale: "ja")
    assert_response :success
    assert_match "新規記事", response.body              # New Article
    assert_match "優先度", response.body                # Priority column
  end

  test "author + article forms render in Japanese" do
    get new_admin_author_path(locale: "ja")
    assert_response :success
    assert_match "著者を作成", response.body            # Create Author
    get new_admin_article_path(locale: "ja")
    assert_response :success
    assert_match "記事を作成", response.body            # Create Article
    assert_match "読了時間", response.body              # Reading time label
  end

  test "settings + colophon + about render in Japanese" do
    get edit_admin_setting_path(locale: "ja")
    assert_response :success
    assert_match "サイト設定", response.body            # Site Settings
    assert_match "テーマカラー", response.body          # Theme colors section
    assert_match "設定を保存", response.body            # Save settings
    get edit_admin_colophon_path(locale: "ja")
    assert_response :success
    assert_match "奥付", response.body                  # Colophon
    get edit_admin_about_path(locale: "ja")
    assert_response :success
    assert_match "概要", response.body                  # About
  end

  test "the admin nav has a language switch that keeps the current page" do
    get admin_tags_path
    assert_select 'a[lang="ja"][href*="locale=ja"]', "JA"
    assert_select 'a[lang="en"][aria-current="true"]', "EN"
  end

  test "the chosen language persists to later admin requests" do
    get admin_tags_path(locale: "ja")
    get admin_tags_path
    assert_match "新規タグ", response.body
    assert_select "html[lang=ja]"
  end

  test "controller flash notices localize to Japanese" do
    post admin_categories_path(locale: "ja"), params: { category: { name: "Flash Test", status: "active", description: "説明" } }
    follow_redirect!
    assert_match "カテゴリーを作成しました。", response.body   # Category created.
  end
end
