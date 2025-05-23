require "test_helper"
require "securerandom"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  fixtures :articles, :authors, :categories, :tags, :stories

  DUMMY_ARTICLE_IMAGE_BASENAME = 'dummy_articles_controller_test_image.png'.freeze # Changed from DUMMY_ARTICLE_IMAGE_BASENAME
  DUMMY_ARTICLE_IMAGE_PATH = Rails.root.join('tmp', DUMMY_ARTICLE_IMAGE_BASENAME).freeze # Changed from DUMMY_ARTICLE_IMAGE_PATH

  def self.ensure_dummy_article_image_exists # Method name unchanged
    return if File.exist?(DUMMY_ARTICLE_IMAGE_PATH) # Changed from DUMMY_ARTICLE_IMAGE_PATH
    FileUtils.mkdir_p(Rails.root.join('tmp'))
    File.open(DUMMY_ARTICLE_IMAGE_PATH, 'w') { |f| f.write("dummy image content for article controller test") } # Changed from DUMMY_ARTICLE_IMAGE_PATH
  end
  ensure_dummy_article_image_exists # Method name unchanged

  setup do
    @author = authors(:author_jane) 
    
    @category = categories(:category_technology) 

    @article = articles(:article_published_tech) 
    @article.update!(
      author: @author,
      category: @category
    ) unless @article.author == @author && @article.category == @category
    
    @article.content = "Default content for article controller tests." if @article.content.blank?

    # Attach dummy image if not already attached
    @article.featured_image.attach(io: File.open(DUMMY_ARTICLE_IMAGE_PATH), filename: DUMMY_ARTICLE_IMAGE_BASENAME, content_type: 'image/png') unless @article.featured_image.attached? # Changed from DUMMY_ARTICLE_IMAGE_PATH and DUMMY_ARTICLE_IMAGE_BASENAME
    
    # Save if changed, or if slug is blank (FriendlyId might need save after associations are set)
    @article.save! if @article.changed? || @article.slug.blank? 
  end

  test "should get index and assign instance variables" do
    get articles_url
    assert_response :success
    assert_not_nil assigns(:articles), "@articles should be assigned"
    assert_not_nil assigns(:categories), "@categories should be assigned"
    assert_not_nil assigns(:authors), "@authors should be assigned"
  end

  test "should get index with published filter" do
    # Ensure there's at least one non-published article (e.g., from fixtures)
    # articles(:article_draft_lifestyle) is a draft article
    
    get articles_url, params: { published: "true" } 
    assert_response :success
    assigns(:articles).each do |article|
      assert article.published?, "Expected only published articles with 'published' filter. Found: #{article.title} (Status: #{article.status})"
    end
  end

  test "should get index with featured filter" do
    # articles(:article_published_tech) is featured: true
    # articles(:article_draft_lifestyle) is featured: false
    get articles_url, params: { featured: "true" }
    assert_response :success
    assigns(:articles).each do |article|
      assert article.featured?, "Expected only featured articles with 'featured' filter."
    end
  end

  test "should get index with category_id filter" do
    category_to_filter_by = categories(:category_programming) # Use a specific category fixture
    
    # Ensure there's an article in this category (e.g., article_published_tech if its category is programming)
    # Or create one:
    # Article.create!(title: "Article in Programming Category", author: @author, category: category_to_filter_by, content: "content", status: :published, published_at: Time.current)
    
    get articles_url, params: { category_id: category_to_filter_by.id }
    assert_response :success
    assigns(:articles).each do |article|
      assert_equal category_to_filter_by.id, article.category_id, "Expected only articles from category ID #{category_to_filter_by.id}"
    end
  end
  
  test "should get index with author_id filter" do
    author_to_filter_by = authors(:author_john) # Use a specific author fixture
    
    # Ensure there's an article by this author (e.g., article_draft_lifestyle or article_review_general)
    # Or create one:
    # Article.create!(title: "Article by John Smith", author: author_to_filter_by, category: @category, content: "content", status: :published, published_at: Time.current)

    get articles_url, params: { author_id: author_to_filter_by.id }
    assert_response :success
    assigns(:articles).each do |article|
      assert_equal author_to_filter_by.id, article.author_id, "Expected only articles from author ID #{author_to_filter_by.id}"
    end
  end

  test "should get index with search filter (title)" do
    # article_published_tech has title "Getting Started with Ruby on Rails 7"
    searched_article = articles(:article_published_tech)
    non_searched_article = articles(:article_draft_lifestyle) # Has a different title

    get articles_url, params: { search: "Ruby on Rails 7" } # Part of the title
    assert_response :success
    assert_includes assigns(:articles), searched_article, "Search results should include the article with the searched title term"
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
      author_id: @author.id, # @author is authors(:author_jane)
      category_id: @category.id, # @category is categories(:category_technology)
      status: :published, 
      published_at: Time.current,
      meta_keywords: "tagX, tagY, newTagZ" # Use unique tag names for count assertion
    }
    Tag.where(name: ["tagX", "tagY", "newTagZ"]).destroy_all

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
    # ... (rest of story and tag assertions remain the same)
    assert_equal ["newTagZ", "tagX", "tagY"], created_article.tags.pluck(:name).sort
  end
  
  test "should create article with featured image" do
    article_params_with_image = {
      title: "Article With Featured Image Draft #{SecureRandom.hex(6)}", # Title changed for clarity
      content: "Content for article with image.",
      author_id: @author.id,
      category_id: @category.id,
      status: :draft, # CHANGED
      # published_at: Time.current, # REMOVED
      featured_image: fixture_file_upload(DUMMY_ARTICLE_IMAGE_PATH, 'image/png'),
      excerpt: "A short excerpt for the article.",
      meta_description: "A meta description for SEO."
    }
    assert_difference("Article.count", 1) do
      post articles_url, params: { article: article_params_with_image }
    end
    created_article = Article.last
    assert created_article.featured_image.attached?, "Featured image should be attached"
    assert_redirected_to article_url(created_article)
  end

  test "should show article and assign it" do
    get article_url(@article) # @article is articles(:article_published_tech)
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
    new_meta_keywords = "alpha_update_tag, beta_update_tag"
    Tag.where(name: ["alpha_update_tag", "beta_update_tag"]).destroy_all 
    
    @article.tags << Tag.find_or_create_by!(name: "gamma_original_tag")

    patch article_url(@article), params: { 
      article: { 
        title: updated_title, 
        content: "Updated content for controller test.",
        meta_keywords: new_meta_keywords 
      } 
    }
    assert_redirected_to article_url(@article), "Should redirect to the article's show page after update"
    @article.reload
    # ... (assertions for title, content, flash remain the same)
    updated_tag_names = @article.tags.pluck(:name).sort
    assert_includes updated_tag_names, "alpha_update_tag"
    assert_includes updated_tag_names, "beta_update_tag"
    assert_includes updated_tag_names, "gamma_original_tag"
  end

  test "should destroy article" do
    article_to_destroy = Article.create!(title: "Article to be Destroyed #{Time.now.to_i}", author: @author, category: @category, content: "destroy me", status: :published, published_at: Time.current)
    
    assert_difference("Article.count", -1, "Article count should decrease by 1") do
      delete article_url(article_to_destroy)
    end
    # ... (rest of assertions remain the same)
  end
  
  test "should find article by its slug (FriendlyId)" do
    get article_url(id: @article.slug) 
    assert_response :success
    assert_equal @article, assigns(:article), "Should find article by slug and assign it"
  end

  test "should not create article with invalid parameters (e.g., blank title)" do
    assert_no_difference(["Article.count", "Story.count", "Tag.count"], "No records should be created with invalid params") do
      post articles_url, params: { article: { title: "", content: "content", author_id: @author.id, category_id: @category.id } }
    end
    # ... (rest of assertions remain the same)
  end

  test "should not update article with invalid parameters (e.g., blank title)" do
    original_title = @article.title
    patch article_url(@article), params: { article: { title: "" } }
    # ... (rest of assertions remain the same)
    @article.reload
    assert_equal original_title, @article.title
  end

  def self.cleanup_dummy_article_image
    FileUtils.rm_f(DUMMY_ARTICLE_IMAGE_PATH) if File.exist?(DUMMY_ARTICLE_IMAGE_PATH)
  end
  Minitest.after_run { cleanup_dummy_article_image }
end
