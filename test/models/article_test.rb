require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  fixtures :authors, :categories, :tags, :articles # Ensure all are explicitly loaded

  setup do
    @author = authors(:author_jane) # Using descriptive fixture name
    @category = categories(:category_technology) # Using descriptive fixture name
    @tag = tags(:tag_ruby) # Using descriptive fixture name

    # Use a specific, published article as the base for many tests
    @article = articles(:article_published_tech) 
    # Ensure associations are set correctly if not already defined in the fixture
    @article.author = @author unless @article.author == @author
    @article.category = @category unless @article.category == @category
    
    # Ensure content is present for tests that might rely on it (e.g. reading_time callback)
    # The actual content is in action_text/rich_texts.yml, this is just to ensure it's not nil.
    @article.content = "Default content for article tests to ensure validity." if @article.content.blank?
    
    # Save any modifications made to the fixture instance if necessary for subsequent assertions
    # (e.g., if slug generation depends on these specific associations or title)
    # However, it's better if fixtures are already in a desired base state.
    # For this refactoring, we assume fixtures are largely usable as-is after referencing descriptively.
    # If @article was modified (e.g. title, author, category), save it.
    # @article.save! if @article.changed? # Only save if changes were made
  end

  # Validations
  test "should be valid with valid attributes" do
    # article_published_tech should be valid by definition from fixtures
    assert @article.valid?, "Article with valid attributes should be valid. Errors: #{@article.errors.full_messages.join(", ")}"
  end

  test "should validate presence of title" do
    @article.title = nil
    assert_not @article.valid?, "Article should be invalid without a title"
    assert_includes @article.errors[:title], "can't be blank"
  end

  test "should validate minimum length of title (5 chars)" do
    @article.title = "four"
    assert_not @article.valid?, "Article title should be too short"
    assert_includes @article.errors[:title], "is too short (minimum is 5 characters)"
  end

  test "should validate maximum length of title (200 chars)" do
    @article.title = "a" * 201
    assert_not @article.valid?, "Article title should be too long"
    assert_includes @article.errors[:title], "is too long (maximum is 200 characters)"
  end

  test "should validate presence of slug" do
    @article.slug = nil
    assert_not @article.valid?, "Article should be invalid without a slug"
    assert_includes @article.errors[:slug], "can't be blank"
  end

  test "should validate uniqueness of slug" do
    # Use a different article fixture for creating a duplicate slug situation
    another_article = articles(:article_draft_lifestyle) 
    
    duplicate_article = Article.new(
      title: "A Completely New Title for Uniqueness Test #{Time.now.to_i}", 
      author: @author,
      category: @category,
      content: "Some content for uniqueness test."
    )
    # Force the slug to be the same as @article (article_published_tech)
    duplicate_article.slug = @article.slug 
    assert_not duplicate_article.valid?, "Article with a duplicate slug ('#{@article.slug}') should be invalid"
    assert_includes duplicate_article.errors[:slug], "has already been taken"
  end

  test "should validate maximum length of meta_description (160 chars)" do
    @article.meta_description = "a" * 161
    assert_not @article.valid?, "Meta description should be too long"
    assert_includes @article.errors[:meta_description], "is too long (maximum is 160 characters)"
  end

  test "should validate maximum length of excerpt (150 chars)" do
    @article.excerpt = "a" * 151
    assert_not @article.valid?, "Excerpt should be too long"
    assert_includes @article.errors[:excerpt], "is too long (maximum is 150 characters)"
  end

  test "should validate presence of content" do
    # To properly test this, we need to ensure content can be nilled.
    # ActionText content needs special handling to be "blank".
    @article.content = "" # Set body to empty
    assert_not @article.valid?, "Article should be invalid without content (empty body)"
    assert_includes @article.errors[:content], "can't be blank"
  end

  test "should validate numericality of reading_time (integer, greater than 0)" do
    @article.reading_time = 0
    assert_not @article.valid?, "Reading time should be invalid if 0"
    assert_includes @article.errors[:reading_time], "must be greater than 0"

    @article.reading_time = -1
    assert_not @article.valid?, "Reading time should be invalid if negative"
    assert_includes @article.errors[:reading_time], "must be greater than 0"
    
    @article.reading_time = 1.5
    assert_not @article.valid?, "Reading time should be invalid if a float"
    assert_includes @article.errors[:reading_time], "must be an integer"

    @article.reading_time = "abc" # Non-numeric
    assert_not @article.valid?, "Reading time should be invalid if not a number"
    assert_includes @article.errors[:reading_time], "is not a number"
    
    @article.reading_time = 5 # Reset to valid for other potential checks on @article
  end

  test "should validate presence of status" do
    @article.status = nil
    assert_not @article.valid?, "Article should be invalid without a status"
    assert_includes @article.errors[:status], "can't be blank"
  end

  test "should validate presence of published_at if status is published" do
    @article.status = :published
    @article.published_at = nil
    assert_not @article.valid?, "Published article should be invalid without published_at"
    assert_includes @article.errors[:published_at], "can't be blank"

    # Reset @article to a consistent state or use a different instance for draft test
    draft_article = articles(:article_draft_lifestyle) # Use a draft fixture
    draft_article.status = :draft # ensure it's draft
    draft_article.published_at = nil 
    assert draft_article.valid?, "Draft article should be valid with nil published_at. Errors: #{draft_article.errors.full_messages.join(", ")}"
  end

  # Associations
  test "should belong to an author" do
    assert_respond_to @article, :author
    assert_instance_of Author, @article.author, "Article's author should be an Author instance"
  end

  test "should belong to a category" do
    assert_respond_to @article, :category
    assert_instance_of Category, @article.category, "Article's category should be a Category instance"
  end

  test "should have and belong to many tags" do
    assert_respond_to @article, :tags
    assert_respond_to @article, :tag_ids 
    
    initial_tag_count = @article.tags.count
    @article.tags << @tag # @tag is tags(:tag_ruby) from setup
    assert_equal initial_tag_count + 1, @article.tags.count, "Tag count should increment"
    assert_includes @article.tags, @tag, "Article should include the added tag"
  end

  test "should have rich text content" do
    assert @article.respond_to?(:content), "Article should respond to :content"
    assert @article.content.respond_to?(:body), "Article's content should respond to :body (ActionText)"
    
    # Assuming article_published_tech_content fixture exists for @article (articles(:article_published_tech))
    # The body might not be a simple string if it contains HTML.
    # A more robust test would check for specific HTML elements or use to_plain_text if appropriate.
    # For now, let's ensure it's not blank if a fixture is set.
    if ActionText::RichText.where(record: @article, name: 'content').exists?
       assert_not @article.content.body.blank?, "Rich text content body should not be blank if fixture exists"
    else # If no explicit ActionText fixture, test assignment
        @article.content = "New rich content for test"
        @article.save!
        @article.reload
        assert_equal "New rich content for test", @article.content.body.to_plain_text
    end
  end

  test "should have one attached featured_image (if validation active)" do
    assert @article.respond_to?(:featured_image), "Article should respond to :featured_image"
    assert @article.featured_image.respond_to?(:attach), "Featured image should be attachable"
    # Note: The model's `validates :featured_image` is commented out.
  end

  # Callbacks
  test "should generate slug from title before validation if title is present and changed" do
    new_article = Article.new(title: "A New Unique Test Article For Slug Gen #{Time.now.to_i}", author: @author, category: @category, content: "Some content.")
    new_article.valid? # Trigger callbacks
    expected_slug = "a-new-unique-test-article-for-slug-gen-#{Time.now.to_i}".parameterize
    assert_equal expected_slug, new_article.slug, "Slug was not generated correctly"
  end
  
  test "should not generate new slug if title is present but unchanged" do
    # Use a freshly created article to avoid state issues from @article
    article_for_slug_stability = Article.create!(title: "Original Title For Slug Stability Test", author: @author, category: @category, content: "Content")
    original_slug = article_for_slug_stability.slug
    
    article_for_slug_stability.meta_description = "Changing something else, not the title."
    article_for_slug_stability.save! 
    
    assert_equal original_slug, article_for_slug_stability.slug, "Slug should not change if title hasn't changed"
  end

  test "should generate an empty slug if title is an empty string (and rely on presence validation for slug)" do
    article_empty_title = Article.new(title: "", author: @author, category: @category, content: "Some content.")
    article_empty_title.valid? 
    assert_equal "", article_empty_title.slug, "Slug should be an empty string if title is empty string"
    assert_includes article_empty_title.errors[:slug], "can't be blank", "Presence validation for slug should fail for empty string slug"
  end
  
  test "should not attempt to generate slug if title is nil (and rely on presence validation for title)" do
    article_nil_title = Article.new(title: nil, author: @author, category: @category, content: "Some content.")
    article_nil_title.valid? 
    assert_nil article_nil_title.slug, "Slug should remain nil if title is nil and slug was not previously set"
    assert_includes article_nil_title.errors[:title], "can't be blank"
  end

  test "should calculate reading time before save" do
    words_per_minute = 200
    word_count = 450 
    content_text = "word " * word_count
    
    article_for_reading_time = Article.new(title: "Test Reading Time Calculation #{Time.now.to_i}", author: @author, category: @category, content: content_text)
    article_for_reading_time.save! 
    
    expected_reading_time = (word_count / words_per_minute.to_f).ceil
    assert_equal expected_reading_time, article_for_reading_time.reading_time, "Reading time was not calculated correctly"
  end

  test "should set default status to draft on new record initialization" do
    new_article_for_default_status = Article.new
    assert_equal "draft", new_article_for_default_status.status, "Default status should be draft for a new article"
  end

  # Scopes
  test "published scope should return only published articles with published_at set" do
    # Uses fixtures: article_published_tech (published), article_draft_lifestyle (draft)
    # Ensure article_published_tech has published_at
    articles(:article_published_tech).update!(published_at: Time.current) unless articles(:article_published_tech).published_at
    
    published_articles_scope = Article.published
    
    assert_includes published_articles_scope, articles(:article_published_tech)
    assert_not_includes published_articles_scope, articles(:article_draft_lifestyle)
    
    # Create an invalid published article (no published_at) to test scope's robustness
    invalid_published = Article.create(title: "Invalid Published #{Time.now.to_i}", author: @author, category: @category, content: "content", status: :published, published_at: nil)
    # This record is invalid due to model validation, but if it existed, scope should exclude it.
    # Note: .create will likely fail or save an invalid record that might not behave as expected.
    # A better test for scope robustness might involve bypassing validations or checking a pre-existing invalid record if possible.
    # For now, we rely on the scope's `where.not(published_at: nil)` part.
    # If invalid_published did manage to save with published_at: nil (e.g. via update_columns):
    # assert_not_includes published_articles_scope, invalid_published
  end

  test "featured scope should return only featured articles" do
    # Assuming article_published_tech is featured: true, article_draft_lifestyle is featured: false from fixtures
    featured_articles_scope = Article.featured
    assert_includes featured_articles_scope, articles(:article_published_tech)
    assert_not_includes featured_articles_scope, articles(:article_draft_lifestyle)
  end
  
  test "not_deleted scope should exclude articles with deleted_at set" do
    # Create a soft-deleted article
    deleted_article = Article.create!(title: "Deleted Article Scope Test #{Time.now.to_i}", author: @author, category: @category, content: "content", status: :published, published_at: Time.current, deleted_at: Time.current)
    
    # Ensure @article (article_published_tech) is not deleted
    @article.update!(deleted_at: nil)

    not_deleted_articles_scope = Article.not_deleted
    assert_includes not_deleted_articles_scope, @article
    assert_not_includes not_deleted_articles_scope, deleted_article
  end

  # Enums
  test "should have correct enum values for status" do
    expected_statuses = %w[draft review published archived]
    assert_equal expected_statuses, Article.statuses.keys, "Enum keys for status are incorrect"
  end

  test "should allow setting and querying status enum values" do
    article_for_enum_test = articles(:article_draft_lifestyle) # Start with a draft

    article_for_enum_test.review!
    assert article_for_enum_test.review?, "Article should be in review status"

    article_for_enum_test.published!
    # Model validation requires published_at for published status
    article_for_enum_test.published_at = Time.current 
    assert article_for_enum_test.save, "Saving published article should be successful"
    assert article_for_enum_test.published?, "Article should be in published status"

    article_for_enum_test.archived!
    assert article_for_enum_test.archived?, "Article should be in archived status"

    article_for_enum_test.draft!
    assert article_for_enum_test.draft?, "Article should be in draft status"
  end
end
