require "application_system_test_case"

class ArticlesTest < ApplicationSystemTestCase
  setup do
    @article = articles(:one)
  end

  test "visiting the index" do
    visit articles_url
    assert_selector "h1", text: "Articles"
  end

  test "should create article" do
    visit articles_url
    click_on "New article"

    fill_in "Author id", with: @article.author_id
    fill_in "Category id", with: @article.category_id
    fill_in "Excerpt", with: @article.excerpt
    check "Featured" if @article.featured
    fill_in "Meta description", with: @article.meta_description
    fill_in "Meta keywords", with: @article.meta_keywords
    fill_in "Published at", with: @article.published_at
    fill_in "Reading time", with: @article.reading_time
    fill_in "Slug", with: @article.slug
    fill_in "Status", with: @article.status
    fill_in "Subtitle", with: @article.subtitle
    fill_in "Title", with: @article.title
    fill_in "View count", with: @article.view_count
    click_on "Create Article"

    assert_text "Article was successfully created"
    click_on "Back"
  end

  test "should update Article" do
    visit article_url(@article)
    click_on "Edit this article", match: :first

    fill_in "Author id", with: @article.author_id
    fill_in "Category id", with: @article.category_id
    fill_in "Excerpt", with: @article.excerpt
    check "Featured" if @article.featured
    fill_in "Meta description", with: @article.meta_description
    fill_in "Meta keywords", with: @article.meta_keywords
    fill_in "Published at", with: @article.published_at.to_s
    fill_in "Reading time", with: @article.reading_time
    fill_in "Slug", with: @article.slug
    fill_in "Status", with: @article.status
    fill_in "Subtitle", with: @article.subtitle
    fill_in "Title", with: @article.title
    fill_in "View count", with: @article.view_count
    click_on "Update Article"

    assert_text "Article was successfully updated"
    click_on "Back"
  end

  test "should destroy Article" do
    visit article_url(@article)
    click_on "Destroy this article", match: :first

    assert_text "Article was successfully destroyed"
  end
end
