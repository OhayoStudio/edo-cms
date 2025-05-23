require "test_helper"

class TagTest < ActiveSupport::TestCase
  fixtures :tags, :articles, :authors, :categories # Ensure all necessary fixtures are loaded

  setup do
    # Use tags(:one) as a general-purpose tag instance for tests.
    # Modifications here are fine as tests are wrapped in transactions.
    @tag = tags(:one)
    @tag.update!(name: "General Tag One", slug: "general-tag-one") # Ensure a known state

    # For association tests
    author = authors(:one)
    category = categories(:one)
    # Ensure author and category are valid if they come from potentially incomplete fixtures
    author.update!(email: "tag_test_author@example.com") unless author.valid?
    category.update!(name: "Tag Test Category", description: "Desc") unless category.valid?
    
    @article_for_association = Article.create!(
      title: "Article for Tag Association Test", 
      author: author, 
      category: category, 
      content: "Some content.", 
      status: :published, 
      published_at: Time.current
    )
  end

  # Validations
  test "should be valid with a unique name" do
    tag = Tag.new(name: "A Valid New Tag #{Time.now.to_i}")
    assert tag.valid?, "Tag should be valid with a unique name. Errors: #{tag.errors.full_messages.join(", ")}"
  end

  test "should validate presence of name" do
    @tag.name = nil
    assert_not @tag.valid?, "Tag should be invalid without a name"
    assert_includes @tag.errors[:name], "can't be blank"
  end

  test "should validate uniqueness of name" do
    existing_tag_name = @tag.name
    duplicate_tag = Tag.new(name: existing_tag_name)
    assert_not duplicate_tag.valid?, "Tag with a duplicate name ('#{existing_tag_name}') should be invalid"
    assert_includes duplicate_tag.errors[:name], "has already been taken"
  end

  test "should validate presence of slug" do
    # Slug is normally generated. To test presence, bypass generation.
    @tag.slug = nil
    assert_not @tag.valid?, "Tag should be invalid without a slug"
    assert_includes @tag.errors[:slug], "can't be blank"
  end

  test "should validate uniqueness of slug" do
    existing_tag_slug = @tag.slug
    duplicate_slug_tag = Tag.new(
      name: "Unique Name for Duplicate Slug Test #{Time.now.to_i}", # Different name
      slug: existing_tag_slug # Use existing tag's slug
    )
    assert_not duplicate_slug_tag.valid?, "Tag with a duplicate slug ('#{existing_tag_slug}') should be invalid"
    assert_includes duplicate_slug_tag.errors[:slug], "has already been taken"
  end

  # Commented out validations in the model are mirrored here.
  # test "should validate maximum length of meta_title (60 chars)" do
  #   @tag.meta_title = "a" * 61
  #   assert_not @tag.valid?
  #   assert_includes @tag.errors[:meta_title], "is too long (maximum is 60 characters)"
  # end

  # test "should validate maximum length of meta_description (160 chars)" do
  #   @tag.meta_description = "a" * 161
  #   assert_not @tag.valid?
  #   assert_includes @tag.errors[:meta_description], "is too long (maximum is 160 characters)"
  # end

  # Associations
  test "should have and belong to many articles" do
    assert_respond_to @tag, :articles, "Tag should respond to :articles"
    assert_respond_to @tag, :article_ids, "Tag should respond to :article_ids helper"

    assert_difference "@tag.articles.count", 1 do
      @tag.articles << @article_for_association
    end
    assert_includes @tag.articles, @article_for_association, "Tag's articles should include the associated article"
    assert_includes @article_for_association.tags, @tag, "Associated article's tags should include the tag"
  end

  # Callbacks
  test "should generate slug from name when name changes on a new record" do
    new_tag_with_name = Tag.new(name: "A Fresh Tag Name For Slug")
    new_tag_with_name.valid? # Trigger before_validation callbacks
    assert_equal "a-fresh-tag-name-for-slug", new_tag_with_name.slug, "Slug was not generated correctly for a new tag"
  end
  
  test "should update slug if name changes on an existing record" do
    existing_tag = Tag.create!(name: "Original Tag Name")
    existing_tag.name = "Updated Tag Name For Slug"
    existing_tag.valid? # Trigger callbacks
    existing_tag.save!
    assert_equal "updated-tag-name-for-slug", existing_tag.slug, "Slug did not update correctly when name changed"
  end

  test "should not generate new slug if name has not changed" do
    tag_with_stable_slug = Tag.create!(name: "Stable Name Tag")
    original_slug = tag_with_stable_slug.slug
    
    tag_with_stable_slug.description = "An updated description for stable slug tag." # Change a non-name attribute
    tag_with_stable_slug.valid? # Trigger callbacks
    tag_with_stable_slug.save!
    
    assert_equal original_slug, tag_with_stable_slug.slug, "Slug should not change if name attribute hasn't changed"
  end

  # Scopes
  test "featured scope should return only featured tags" do
    featured_tag = Tag.create!(name: "Featured Test Tag #{Time.now.to_i}", featured: true)
    non_featured_tag = Tag.create!(name: "Non-Featured Test Tag #{Time.now.to_i}", featured: false)

    featured_tags_scope = Tag.featured
    assert_includes featured_tags_scope, featured_tag, "Scope should include featured tag"
    assert_not_includes featured_tags_scope, non_featured_tag, "Scope should exclude non-featured tag"
  end

  test "not_deleted scope should exclude tags with a deleted_at timestamp" do
    not_deleted_tag = Tag.create!(name: "Not Deleted Tag #{Time.now.to_i}", deleted_at: nil)
    deleted_tag = Tag.create!(name: "Soft Deleted Tag #{Time.now.to_i}", deleted_at: Time.current)

    not_deleted_scope = Tag.not_deleted
    assert_includes not_deleted_scope, not_deleted_tag, "Scope should include tag without deleted_at"
    assert_not_includes not_deleted_scope, deleted_tag, "Scope should exclude tag with deleted_at"
  end

  test "with_articles scope should return tags associated with at least one article" do
    tag_with_article = Tag.create!(name: "Tag With Article #{Time.now.to_i}")
    tag_without_article = Tag.create!(name: "Tag Without Article #{Time.now.to_i}")
    
    tag_with_article.articles << @article_for_association # Associate an article
    
    tags_with_articles_scope = Tag.with_articles
    assert_includes tags_with_articles_scope, tag_with_article, "Scope should include tag associated with an article"
    assert_not_includes tags_with_articles_scope, tag_without_article, "Scope should exclude tag with no articles"
  end

  # Methods
  test "article_count should return the count of published articles associated with the tag" do
    tag_for_article_count = Tag.create!(name: "Tag for Article Count #{Time.now.to_i}")
    author = authors(:one)     # Re-use from setup or ensure valid
    category = categories(:one) # Re-use from setup or ensure valid

    # Create articles and associate them with the tag
    published_article1 = Article.create!(title: "Published Article 1 For Tag Count", author: author, category: category, content: "Content", status: :published, published_at: Time.current)
    published_article2 = Article.create!(title: "Published Article 2 For Tag Count", author: author, category: category, content: "Content", status: :published, published_at: Time.current)
    draft_article = Article.create!(title: "Draft Article For Tag Count", author: author, category: category, content: "Content", status: :draft)

    tag_for_article_count.articles << published_article1
    tag_for_article_count.articles << published_article2
    tag_for_article_count.articles << draft_article
    
    assert_equal 2, tag_for_article_count.article_count, "article_count did not return correct number of published articles"
  end
end
