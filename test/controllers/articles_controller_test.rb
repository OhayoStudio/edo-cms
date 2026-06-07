require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  fixtures :articles, :authors, :categories, :tags, :stories

  setup do
    @article = articles(:article_published_tech) # featured, published
    @draft   = articles(:article_draft_lifestyle) # draft
  end

  test "should get index and assign instance variables" do
    get articles_url
    assert_response :success
    assert_not_nil assigns(:articles), "@articles should be assigned"
    assert_not_nil assigns(:categories), "@categories should be assigned"
    assert_not_nil assigns(:authors), "@authors should be assigned"
  end

  test "index lists only published articles" do
    get articles_url
    assert_response :success
    assert_includes assigns(:articles), @article
    assert_not_includes assigns(:articles), @draft, "Drafts should not appear on the index"
  end

  test "index featured filter returns only featured articles" do
    get articles_url, params: { featured: "true" }
    assert_response :success
    assigns(:articles).each do |article|
      assert article.featured?, "Expected only featured articles with the featured filter"
    end
    assert_includes assigns(:articles), @article
  end

  test "index category_id filter returns only matching articles" do
    category = @article.category
    get articles_url, params: { category_id: category.id }
    assert_response :success
    assigns(:articles).each do |article|
      assert_equal category.id, article.category_id
    end
  end

  test "index author_id filter returns only matching articles" do
    author = @article.author
    get articles_url, params: { author_id: author.id }
    assert_response :success
    assigns(:articles).each do |article|
      assert_equal author.id, article.author_id
    end
  end

  test "index search filter matches on title" do
    get articles_url, params: { search: "Ruby on Rails 7" }
    assert_response :success
    assert_includes assigns(:articles), @article,
                    "Search should include the article whose title matches"
    assert_not_includes assigns(:articles), @draft,
                        "Search should exclude non-matching articles"
  end

  test "should show a published article by id and assign it" do
    get article_url(id: @article.id)
    assert_response :success
    assert_equal @article, assigns(:article), "@article should be assigned correctly"
  end

  test "should show a published article by its FriendlyId slug" do
    get article_url(id: @article.slug)
    assert_response :success
    assert_equal @article, assigns(:article), "Should find the article by slug"
  end

  test "should redirect to root for a non-published article" do
    # The published-only scope raises RecordNotFound for a draft, which
    # ApplicationController rescues into a redirect to the root path.
    get article_url(id: @draft.slug)
    assert_redirected_to root_path
  end
end
