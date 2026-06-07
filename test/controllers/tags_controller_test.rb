require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  fixtures :tags, :articles, :authors, :categories

  setup do
    @tag = tags(:tag_ruby)
    @published_article = articles(:article_published_tech) # status: :published
    @draft_article = articles(:article_draft_lifestyle)    # status: :draft

    @tag.articles << @published_article unless @tag.articles.include?(@published_article)
    @tag.articles << @draft_article unless @tag.articles.include?(@draft_article)
  end

  test "should get index and assign tags" do
    get tags_url
    assert_response :success
    assert_not_nil assigns(:tags), "@tags should be assigned"
  end

  test "should show tag by id, assign collections, and render articles/index" do
    get tag_url(id: @tag.id)
    assert_response :success

    assert_equal @tag, assigns(:tag), "@tag should be assigned correctly"
    assert_not_nil assigns(:articles), "@articles should be assigned"
    assert_not_nil assigns(:tags), "All @tags should be assigned for the sidebar"
    assert_not_nil assigns(:categories), "All @categories should be assigned for the sidebar"
    assert_template "articles/index", "Should render the articles/index template"

    assert_includes assigns(:articles), @published_article
    assert_not_includes assigns(:articles), @draft_article,
                        "Only published articles should be listed for a tag"
  end

  test "should show tag by its FriendlyId slug" do
    get tag_url(id: @tag.slug)
    assert_response :success
    assert_equal @tag, assigns(:tag), "Should find the tag by slug"
  end
end
