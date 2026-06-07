require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  fixtures :categories, :articles, :authors

  setup do
    @category = categories(:category_technology)
    @published_article = articles(:article_published_tech) # status: :published
    @published_article.update!(category: @category) unless @published_article.category == @category
  end

  test "should get index and assign categories" do
    get categories_url
    assert_response :success
    assert_not_nil assigns(:categories), "@categories should be assigned"
  end

  test "should show category by id, assign collections, and render articles/index" do
    get category_url(id: @category.id)
    assert_response :success

    assert_equal @category, assigns(:category), "@category should be assigned correctly"
    assert_not_nil assigns(:articles), "@articles should be assigned"
    assert_not_nil assigns(:categories), "All @categories should be assigned for the sidebar"
    assert_template "articles/index", "Should render the articles/index template"

    assigns(:articles).each do |article|
      assert_equal @category.id, article.category_id, "Listed articles should belong to the category"
      assert article.published?, "Only published articles should be listed for a category"
    end
    assert_includes assigns(:articles), @published_article
  end

  test "should show category by its FriendlyId slug" do
    get category_url(id: @category.slug)
    assert_response :success
    assert_equal @category, assigns(:category), "Should find the category by slug"
  end
end
