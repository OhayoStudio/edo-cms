require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @article = articles(:one)
  end

  test "should get index" do
    get articles_url
    assert_response :success
  end

  test "should get new" do
    get new_article_url
    assert_response :success
  end

  test "should create article" do
    assert_difference("Article.count") do
      post articles_url, params: { article: { author_id: @article.author_id, category_id: @article.category_id, excerpt: @article.excerpt, featured: @article.featured, meta_description: @article.meta_description, meta_keywords: @article.meta_keywords, published_at: @article.published_at, reading_time: @article.reading_time, slug: @article.slug, status: @article.status, subtitle: @article.subtitle, title: @article.title, view_count: @article.view_count } }
    end

    assert_redirected_to article_url(Article.last)
  end

  test "should show article" do
    get article_url(@article)
    assert_response :success
  end

  test "should get edit" do
    get edit_article_url(@article)
    assert_response :success
  end

  test "should update article" do
    patch article_url(@article), params: { article: { author_id: @article.author_id, category_id: @article.category_id, excerpt: @article.excerpt, featured: @article.featured, meta_description: @article.meta_description, meta_keywords: @article.meta_keywords, published_at: @article.published_at, reading_time: @article.reading_time, slug: @article.slug, status: @article.status, subtitle: @article.subtitle, title: @article.title, view_count: @article.view_count } }
    assert_redirected_to article_url(@article)
  end

  test "should destroy article" do
    assert_difference("Article.count", -1) do
      delete article_url(@article)
    end

    assert_redirected_to articles_url
  end
end
