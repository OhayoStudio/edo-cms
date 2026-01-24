require "test_helper"

class TagTest < ActiveSupport::TestCase
  fixtures :tags, :articles, :authors, :categories # Ensure all necessary fixtures are loaded

  setup do
    # Use a descriptive fixture name, e.g., an active tag.
    @tag = tags(:tag_ruby)

    # For association tests, ensure related fixtures are valid and descriptive.
    @author_for_tag_association = authors(:author_jane)
    @category_for_tag_association = categories(:category_technology)

    # Use a specific article fixture or create one for clarity in association tests.
    @article_for_association = articles(:article_published_tech)
    # Ensure this article is suitable for association (e.g., correct author/category if not set by fixture)
    @article_for_association.update!(
      author: @author_for_tag_association,
      category: @category_for_tag_association
    ) unless @article_for_association.author == @author_for_tag_association && @article_for_association.category == @category_for_tag_association
  end

  # Validations
  test "should be valid with a unique name" do
    tag = Tag.new(name: "A Valid New Unique Tag #{Time.now.to_i}") # Ensure unique name
    assert tag.valid?, "Tag should be valid with a unique name. Errors: #{tag.errors.full_messages.join(", ")}"
  end

  test "should validate presence of name" do
    @tag.name = nil
    assert_not @tag.valid?, "Tag should be invalid without a name"
    assert_includes @tag.errors[:name], "can't be blank"
  end

  test "should validate uniqueness of name" do
    existing_tag_name = @tag.name # @tag is tags(:tag_ruby)
    duplicate_tag = Tag.new(name: existing_tag_name)
    assert_not duplicate_tag.valid?, "Tag with a duplicate name ('#{existing_tag_name}') should be invalid"
    assert_includes duplicate_tag.errors[:name], "has already been taken"
  end

  test "should validate presence of slug" do
    @tag.slug = nil
    assert_not @tag.valid?, "Tag should be invalid without a slug"
    assert_includes @tag.errors[:slug], "can't be blank"
  end

  test "should validate uniqueness of slug" do
    existing_tag_slug = @tag.slug # @tag is tags(:tag_ruby)
    duplicate_slug_tag = Tag.new(
      name: "Unique Name for Duplicate Slug Test #{Time.now.to_i}",
      slug: existing_tag_slug
    )
    assert_not duplicate_slug_tag.valid?, "Tag with a duplicate slug ('#{existing_tag_slug}') should be invalid"
    # assert_includes duplicate_slug_tag.errors[:slug], "has already been taken"
  end

  # Associations
  test "should have and belong to many articles" do
    assert_respond_to @tag, :articles, "Tag should respond to :articles"
    assert_respond_to @tag, :article_ids, "Tag should respond to :article_ids helper"

    initial_article_count = @tag.articles.count
    @tag.articles << @article_for_association

    assert_equal initial_article_count + 1, @tag.articles.count, "Article count for tag should increment"
    assert_includes @tag.articles, @article_for_association, "Tag's articles should include the associated article"
    assert_includes @article_for_association.tags, @tag, "Associated article's tags should include the tag"
  end

  # Callbacks
  test "should generate slug from name when name changes on a new record" do
    new_tag_for_slug_test = Tag.new(name: "A Fresh Tag Name For Slug Test #{Time.now.to_i}")
    new_tag_for_slug_test.valid?
    expected_slug = "a-fresh-tag-name-for-slug-test-#{Time.now.to_i}".parameterize
    assert_equal expected_slug, new_tag_for_slug_test.slug, "Slug was not generated correctly for a new tag"
  end

  test "should update slug if name changes on an existing record" do
    existing_tag_for_slug_update = Tag.create!(name: "Original Tag Name For Update #{Time.now.to_i}")
    updated_name = "Updated Tag Name For Slug Test #{Time.now.to_i}"
    existing_tag_for_slug_update.name = updated_name
    existing_tag_for_slug_update.valid?
    existing_tag_for_slug_update.save!
    expected_updated_slug = updated_name.parameterize
    assert_equal expected_updated_slug, existing_tag_for_slug_update.slug, "Slug did not update correctly when name changed"
  end

  test "should not generate new slug if name has not changed" do
    tag_with_stable_slug = Tag.create!(name: "Stable Name Tag For No Slug Change #{Time.now.to_i}")
    original_slug = tag_with_stable_slug.slug

    tag_with_stable_slug.description = "An updated description for stable slug tag, name unchanged."
    tag_with_stable_slug.valid?
    tag_with_stable_slug.save!

    assert_equal original_slug, tag_with_stable_slug.slug, "Slug should not change if name attribute hasn't changed"
  end

  # Scopes
  test "featured scope should return only featured tags" do
    # Assuming tag_ruby and tag_rails are featured: true, tag_javascript is featured: false from fixtures
    featured_tags_scope = Tag.featured
    assert_includes featured_tags_scope, tags(:tag_ruby)
    assert_includes featured_tags_scope, tags(:tag_rails)
    assert_not_includes featured_tags_scope, tags(:tag_javascript)
  end

  test "not_deleted scope should exclude tags with a deleted_at timestamp" do
    # Assuming tag_ruby is not deleted, and tag_deleted is soft-deleted from fixtures
    not_deleted_scope = Tag.not_deleted
    assert_includes not_deleted_scope, tags(:tag_ruby)
    assert_not_includes not_deleted_scope, tags(:tag_deleted)
  end

  test "with_articles scope should return tags associated with at least one article" do
    tag_definitely_with_article = tags(:tag_ruby) # This tag should have articles associated in setup or fixtures
    tag_definitely_with_article.articles << @article_for_association unless tag_definitely_with_article.articles.include?(@article_for_association)

    tag_without_article = Tag.create!(name: "Tag Without Any Articles #{Time.now.to_i}")

    tags_with_articles_scope = Tag.with_articles
    assert_includes tags_with_articles_scope, tag_definitely_with_article, "Scope should include tag associated with an article"
    assert_not_includes tags_with_articles_scope, tag_without_article, "Scope should exclude tag with no articles"
  end

  # Methods
  test "article_count should return the count of published articles associated with the tag" do
    tag_for_article_count_method = tags(:tag_rails) # Use a specific tag
    # Ensure predictable article state for this tag
    tag_for_article_count_method.articles.destroy_all

    author = authors(:author_jane)
    category = categories(:category_programming)

    # Create articles and associate them with the tag
    published_article1 = Article.create!(title: "Published Rails Article 1", author: author, category: category, content: "Content", status: :published, published_at: Time.current)
    published_article2 = Article.create!(title: "Published Rails Article 2", author: author, category: category, content: "Content", status: :published, published_at: Time.current)
    draft_article = Article.create!(title: "Draft Rails Article", author: author, category: category, content: "Content", status: :draft)

    tag_for_article_count_method.articles << published_article1
    tag_for_article_count_method.articles << published_article2
    tag_for_article_count_method.articles << draft_article

    assert_equal 2, tag_for_article_count_method.article_count, "article_count did not return correct number of published articles"
  end
end
