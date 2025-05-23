require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  fixtures :articles, :authors, :categories, :tags, :stories

  DUMMY_ARTICLE_IMAGE_BASENAME = 'dummy_article_controller_test_image.png'.freeze
  DUMMY_ARTICLE_IMAGE_PATH = Rails.root.join('tmp', DUMMY_ARTICLE_IMAGE_BASENAME).freeze

  def self.ensure_dummy_article_image_exists
    return if File.exist?(DUMMY_ARTICLE_IMAGE_PATH)
    FileUtils.mkdir_p(Rails.root.join('tmp'))
    File.open(DUMMY_ARTICLE_IMAGE_PATH, 'w') { |f| f.write("dummy image content for article controller test") }
  end
  ensure_dummy_article_image_exists

  setup do
    @author = authors(:one)
    # Ensure fixture data is unique to avoid validation conflicts during test runs
    @author.update!(email: "author_articles_ctrl_test@example.com", slug: "author-articles-ctrl-test-slug")
    
    @category = categories(:one)
    @category.update!(name: "Category Articles Ctrl Test", slug: "category-articles-ctrl-test-slug", description: "Test desc for articles ctrl")

    @article = articles(:one)
    @article.update!(
      author: @author,
      category: @category,
      title: "Setup Article Title For Controller Test", # Unique title
      content: "Initial content for setup article in controller test.",
      status: :published, # Ensure it's published for tests that expect it
      published_at: Time.current
    )
    unless @article.featured_image.attached?
      @article.featured_image.attach(io: File.open(DUMMY_ARTICLE_IMAGE_PATH), filename: DUMMY_ARTICLE_IMAGE_BASENAME, content_type: 'image/png')
    end
  end

  test "should get index and assign instance variables" do
    get articles_url
    assert_response :success
    assert_not_nil assigns(:articles), "@articles should be assigned"
    assert_not_nil assigns(:categories), "@categories should be assigned"
    assert_not_nil assigns(:authors), "@authors should be assigned"
  end

  test "should get index with published filter" do
    # Ensure there's at least one non-published article to filter out
    Article.create!(title: "Draft Filter Test Article", author: @author, category: @category, content: "content", status: :draft)
    
    get articles_url, params: { published: "true" } # Use string "true" as params are often strings
    assert_response :success
    assigns(:articles).each do |article|
      assert article.published?, "Expected only published articles with 'published' filter. Found: #{article.title} (Status: #{article.status})"
    end
  end

  test "should get index with featured filter" do
    # Ensure there's at least one featured and one non-featured article
    Article.create!(title: "Featured Filter Test Article", author: @author, category: @category, content: "content", status: :published, published_at: Time.current, featured: true)
    Article.create!(title: "Non-Featured Filter Test Article", author: @author, category: @category, content: "content", status: :published, published_at: Time.current, featured: false)

    get articles_url, params: { featured: "true" }
    assert_response :success
    assigns(:articles).each do |article|
      assert article.featured?, "Expected only featured articles with 'featured' filter."
    end
  end

  test "should get index with category_id filter" do
    category_to_filter_by = categories(:two)
    category_to_filter_by.update!(name: "Category For ID Filter Test", description: "Desc for ID filter")
    
    article_in_filtered_category = Article.create!(title: "Article in Specific Category", author: @author, category: category_to_filter_by, content: "content", status: :published, published_at: Time.current)
    # Ensure @article (from setup) is in a different category for a robust test
    @article.update!(category: categories(:one)) # Assuming categories(:one) is different from categories(:two)

    get articles_url, params: { category_id: category_to_filter_by.id }
    assert_response :success
    assigns(:articles).each do |article|
      assert_equal category_to_filter_by.id, article.category_id, "Expected only articles from category ID #{category_to_filter_by.id}"
    end
    assert_includes assigns(:articles), article_in_filtered_category
    assert_not_includes assigns(:articles), @article unless @article.category_id == category_to_filter_by.id
  end
  
  test "should get index with author_id filter" do
    author_to_filter_by = authors(:two)
    author_to_filter_by.update!(email: "author_filter_test@example.com", first_name: "FilterAuth", last_name: "Test")
    
    article_by_filtered_author = Article.create!(title: "Article by Specific Author", author: author_to_filter_by, category: @category, content: "content", status: :published, published_at: Time.current)
    # Ensure @article (from setup) has a different author for a robust test
    @article.update!(author: authors(:one)) # Assuming authors(:one) is different from authors(:two)

    get articles_url, params: { author_id: author_to_filter_by.id }
    assert_response :success
    assigns(:articles).each do |article|
      assert_equal author_to_filter_by.id, article.author_id, "Expected only articles from author ID #{author_to_filter_by.id}"
    end
    assert_includes assigns(:articles), article_by_filtered_author
    assert_not_includes assigns(:articles), @article unless @article.author_id == author_to_filter_by.id
  end

  test "should get index with search filter (title)" do
    unique_title_for_search = "UniqueSearchableTitleForArticleTest#{Time.now.to_i}"
    searched_article = Article.create!(title: unique_title_for_search, author: @author, category: @category, content: "content", status: :published, published_at: Time.current)
    non_searched_article = Article.create!(title: "Another NonSearched Article", author: @author, category: @category, content: "content", status: :published, published_at: Time.current)

    get articles_url, params: { search: unique_title_for_search }
    assert_response :success
    assert_includes assigns(:articles), searched_article, "Search results should include the article with the searched title"
    assert_not_includes assigns(:articles), non_searched_article, "Search results should not include articles that don't match"
  end

  test "should get new and assign a new article" do
    get new_article_url
    assert_response :success
    assert_instance_of Article, assigns(:article), "@article should be a new Article instance"
    assert assigns(:article).new_record?, "Assigned @article should be a new record"
  end

  test "should create article, associated story, and tags" do
    article_params = {
      title: "New Created Article For StoryAndTags #{Time.now.to_i}",
      content: "Content for article with story and tags.",
      author_id: @author.id,
      category_id: @category.id,
      status: :published, # To ensure story is also marked published
      published_at: Time.current,
      meta_keywords: "tagA, tagB, newTagC"
    }
    # Ensure tags don't exist to accurately test Tag.count difference
    Tag.where(name: ["tagA", "tagB", "newTagC"]).destroy_all

    assert_difference("Article.count", 1, "Article count should increment by 1") do
      assert_difference("Story.count", 1, "Story count should increment by 1") do
        assert_difference("Tag.count", 3, "Tag count should increment by 3 for new tags") do
          post articles_url, params: { article: article_params }
        end
      end
    end

    created_article = Article.last
    assert_redirected_to article_url(created_article), "Should redirect to the created article's show page"
    assert_equal "Article was successfully created.", flash[:notice], "Flash notice for creation should be set"
    
    story = Story.find_by(storyable: created_article)
    assert_not_nil story, "A Story should be created for the new article"
    assert_equal created_article.slug, story.slug, "Story slug should match article slug"
    assert_equal created_article.featured, story.is_top, "Story is_top should match article featured status"
    assert story.is_published, "Story should be published as article is published"
    assert_equal created_article.published_at.to_s, story.published_at.to_s, "Story published_at should match article"

    assert_equal ["newTagC", "tagA", "tagB"], created_article.tags.pluck(:name).sort # Order might vary
  end
  
  test "should create article with featured image" do
    article_params_with_image = {
      title: "Article With Featured Image #{Time.now.to_i}",
      content: "Content for article with image.",
      author_id: @author.id,
      category_id: @category.id,
      status: :published,
      published_at: Time.current,
      featured_image: fixture_file_upload(DUMMY_ARTICLE_IMAGE_PATH, 'image/png')
    }
    assert_difference("Article.count", 1) do
      post articles_url, params: { article: article_params_with_image }
    end
    created_article = Article.last
    assert created_article.featured_image.attached?, "Featured image should be attached"
    assert_redirected_to article_url(created_article)
  end

  test "should show article and assign it" do
    get article_url(@article)
    assert_response :success
    assert_equal @article, assigns(:article), "@article instance variable should be assigned correctly"
  end

  test "should get edit for an article and assign it" do
    get edit_article_url(@article)
    assert_response :success
    assert_equal @article, assigns(:article), "@article instance variable should be assigned for edit"
  end

  test "should update article and its tags" do
    updated_title = "Updated Article Title For Controller Test #{Time.now.to_i}"
    new_meta_keywords = "alpha_tag, beta_tag"
    Tag.where(name: ["alpha_tag", "beta_tag"]).destroy_all # Ensure they are new
    
    # Existing tag to ensure it's handled as per controller logic (current logic adds, doesn't remove)
    @article.tags << Tag.find_or_create_by!(name: "gamma_tag")

    patch article_url(@article), params: { 
      article: { 
        title: updated_title, 
        content: "Updated content for controller test.",
        meta_keywords: new_meta_keywords 
      } 
    }
    assert_redirected_to article_url(@article), "Should redirect to the article's show page after update"
    @article.reload

    assert_equal updated_title, @article.title, "Article title should be updated"
    assert_equal "Updated content for controller test.", @article.content.body.to_plain_text, "Article content should be updated"
    assert_equal "Article was successfully updated.", flash[:notice]

    updated_tag_names = @article.tags.pluck(:name).sort
    assert_includes updated_tag_names, "alpha_tag"
    assert_includes updated_tag_names, "beta_tag"
    # Current controller logic for generate_tags adds new tags but doesn't remove old ones not in meta_keywords.
    # So, "gamma_tag" should still be present.
    assert_includes updated_tag_names, "gamma_tag", "Old tags should persist based on current generate_tags logic"
  end

  test "should destroy article" do
    # If Article has dependent: :destroy for stories, Story.count would change.
    # Current ArticlesController#create creates a Story, but Article model doesn't define has_one/has_many :stories.
    # Thus, @article.destroy! will likely NOT destroy the Story unless a DB cascade or model callback handles it.
    # For this test, we focus on Article destruction. Story destruction test should be more specific if needed.
    article_to_destroy = Article.create!(title: "Article to be Destroyed", author: @author, category: @category, content: "destroy me", status: :published, published_at: Time.current)
    # Optionally create a story for it if we want to test if it gets orphaned or deleted (requires model setup)
    # Story.create!(storyable: article_to_destroy, slug: article_to_destroy.slug)

    assert_difference("Article.count", -1, "Article count should decrease by 1") do
      delete article_url(article_to_destroy)
    end

    assert_redirected_to articles_url, "Should redirect to articles index after destruction"
    assert_equal "Article was successfully destroyed.", flash[:notice], "Flash notice for destruction should be set"
  end
  
  test "should find article by its slug (FriendlyId)" do
    get article_url(id: @article.slug) # Rails automatically uses to_param, which is slug for FriendlyId
    assert_response :success
    assert_equal @article, assigns(:article), "Should find article by slug and assign it"
  end

  test "should not create article with invalid parameters (e.g., blank title)" do
    assert_no_difference(["Article.count", "Story.count", "Tag.count"], "No records should be created with invalid params") do
      post articles_url, params: { article: { title: "", content: "content", author_id: @author.id, category_id: @category.id } }
    end
    assert_response :unprocessable_entity, "Response should be :unprocessable_entity for invalid params"
    assert_template :new, "Should re-render the 'new' template"
  end

  test "should not update article with invalid parameters (e.g., blank title)" do
    original_title = @article.title
    patch article_url(@article), params: { article: { title: "" } }
    assert_response :unprocessable_entity, "Response should be :unprocessable_entity for invalid update params"
    assert_template :edit, "Should re-render the 'edit' template"
    @article.reload
    assert_equal original_title, @article.title, "Article title should not change with invalid update params"
  end

  # Cleanup dummy file after all tests in this class are done.
  # Note: This runs once after all tests, not after each test.
  # If tests needed independent dummy files, setup/teardown per test would be better.
  def self.cleanup_dummy_article_image
    FileUtils.rm_f(DUMMY_ARTICLE_IMAGE_PATH) if File.exist?(DUMMY_ARTICLE_IMAGE_PATH)
  end
  Minitest.after_run { cleanup_dummy_article_image } # Standard Minitest hook
end
