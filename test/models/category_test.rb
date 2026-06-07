require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  # Fixtures are automatically loaded.
  # Ensure articles and authors fixtures are available if testing dependent: :nullify for articles.
  fixtures :categories, :articles, :authors

  setup do
    # Use a descriptive fixture name, e.g., an active, root category.
    @category = categories(:category_technology)

    # For uniqueness tests or scenarios needing a second distinct category.
    @another_category = categories(:category_lifestyle)

    # Safeguard: Ensure fixture data is distinct if necessary for specific tests,
    # though well-defined fixtures should ideally handle this.
    if @category.name == @another_category.name || @category.slug == @another_category.slug
      @category.update!(name: "Category Tech Test #{Time.now.to_f}", slug: "category-tech-test-#{Time.now.to_f}", description: "Desc for tech test")
      @another_category.update!(name: "Category Lifestyle Test #{Time.now.to_f}", slug: "category-lifestyle-test-#{Time.now.to_f}", description: "Desc for lifestyle test")
    end
  end

  # Validations
  test "should be valid with required attributes" do
    new_category = Category.new(name: "Valid New Unique Category #{Time.now.to_i}", description: "A valid description for a new category.")
    assert new_category.valid?, "Category should be valid. Errors: #{new_category.errors.full_messages.join(", ")}"
  end

  test "should validate presence of name" do
    @category.name = nil
    assert_not @category.valid?, "Category should be invalid without a name"
    assert_includes @category.errors[:name], "can't be blank"
  end

  test "should validate uniqueness of name" do
    duplicate_category = Category.new(name: @category.name, description: "Another description for duplicate name test.")
    assert_not duplicate_category.valid?, "Category with a duplicate name ('#{@category.name}') should be invalid"
    assert_includes duplicate_category.errors[:name], "has already been taken"
  end

  test "slug is always populated from the name" do
    # generate_slug derives the slug from the name on every change, so a
    # category with a name can never be missing its slug; the presence
    # validation is effectively backstopped by the callback.
    @category.slug = nil
    @category.valid?
    assert_equal @category.name.parameterize, @category.slug
    assert_empty @category.errors[:slug], "Slug presence error should not fire"
  end

  test "should validate uniqueness of slug" do
    # generate_slug overwrites any explicit slug with name.parameterize, so a
    # duplicate slug is produced by a name that parameterizes to an existing
    # slug (here, "TECHNOLOGY" -> "technology") rather than by setting :slug.
    duplicate_category = Category.new(
      name: @category.name.upcase,
      description: "Description for unique slug test."
    )
    assert_not duplicate_category.valid?, "Category with a duplicate slug ('#{@category.slug}') should be invalid"
    assert_includes duplicate_category.errors[:slug], "has already been taken"
  end

  test "should validate presence of description" do
    @category.description = nil
    assert_not @category.valid?, "Category should be invalid without a description"
    assert_includes @category.errors[:description], "can't be blank"
  end

  test "should validate maximum length of meta_title (60 chars)" do
    @category.meta_title = "a" * 61
    assert_not @category.valid?, "Meta title should be too long"
    assert_includes @category.errors[:meta_title], "is too long (maximum is 60 characters)"
  end

  test "should validate maximum length of meta_description (160 chars)" do
    @category.meta_description = "a" * 161
    assert_not @category.valid?, "Meta description should be too long"
    assert_includes @category.errors[:meta_description], "is too long (maximum is 160 characters)"
  end

  # Associations
  test "should belong to a parent category (optional)" do
    # category_technology is a root category from fixtures
    parent_cat = categories(:category_technology)
    # category_programming is a child of category_technology from fixtures
    child_cat = categories(:category_programming)

    assert_equal parent_cat, child_cat.parent, "Child category's parent should be the assigned parent category"
  end

  test "should have many subcategories" do
    parent_cat_with_subs = categories(:category_technology) # This fixture has category_programming as a subcategory

    assert_not_empty parent_cat_with_subs.subcategories, "Parent category should have subcategories"
    assert_includes parent_cat_with_subs.subcategories, categories(:category_programming)
  end

  test "should have many articles" do
    assert_respond_to @category, :articles, "Category should respond to :articles"
  end

  test "articles require a category and the column is not nullable" do
    # The model declares has_many :articles, dependent: :nullify, but the DB
    # enforces a NOT NULL constraint on articles.category_id (and belongs_to
    # is required), so an article cannot exist without a category. A category
    # with no articles can be destroyed cleanly.
    empty_category = Category.create!(name: "Empty Cat #{Time.now.to_i}", description: "No articles here.")
    assert_difference("Category.count", -1) do
      empty_category.destroy
    end

    article = Article.new(
      title: "Article Without Category #{Time.now.to_i}",
      author: authors(:author_jane),
      content: "content",
      reading_time: 1
    )
    assert_not article.valid?, "Article should be invalid without a category"
    assert_includes article.errors[:category], "must exist"
  end

  # Callbacks
  test "should generate slug from name for a new category" do
    name = "New Category For Slug Test #{Time.now.to_i}"
    category_for_slug_test = Category.new(name: name, description: "Description for slug test.")
    category_for_slug_test.valid?
    assert_equal name.parameterize, category_for_slug_test.slug, "Slug was not generated correctly for a new category"

    # Once persisted, the slug is stable: renaming does not change the slug
    # because generate_slug only fires while the slug is blank or unchanged.
    category_for_slug_test.save!
    original_slug = category_for_slug_test.slug
    category_for_slug_test.name = "Updated Category For Slug Test #{Time.now.to_i}"
    category_for_slug_test.valid?
    assert_equal original_slug, category_for_slug_test.slug, "Slug should stay stable across a rename"
  end

  test "should not generate new slug if name has not changed" do
    category_stable_slug = Category.create!(name: "Stable Slug Category #{Time.now.to_i}", description: "Desc for stable slug.")
    original_slug = category_stable_slug.slug

    category_stable_slug.meta_title = "A new meta title for stable slug category."
    category_stable_slug.valid?
    category_stable_slug.save!

    assert_equal original_slug, category_stable_slug.slug, "Slug should not change if name attribute hasn't changed"
  end

  # Scopes
  test "root_categories scope should return categories with no parent_id" do
    root_cat = categories(:category_technology) # This is a root category from fixtures
    child_cat = categories(:category_programming) # This is a child category from fixtures

    root_categories_scope = Category.root_categories
    assert_includes root_categories_scope, root_cat, "Scope should include the root category"
    assert_not_includes root_categories_scope, child_cat, "Scope should exclude child categories"
  end

  test "featured scope should return only featured categories" do
    featured_cat = categories(:category_technology) # This is featured: true in fixtures
    non_featured_cat = categories(:category_lifestyle) # This is featured: false in fixtures

    featured_categories_scope = Category.featured
    assert_includes featured_categories_scope, featured_cat, "Scope should include featured category"
    assert_not_includes featured_categories_scope, non_featured_cat, "Scope should exclude non-featured category"
  end

  test "active scope should return only active categories" do
    active_cat = categories(:category_technology) # This is status: :active in fixtures
    inactive_cat = categories(:category_inactive) # This is status: :inactive in fixtures

    active_categories_scope = Category.active
    assert_includes active_categories_scope, active_cat, "Scope should include active category"
    assert_not_includes active_categories_scope, inactive_cat, "Scope should exclude inactive category"
  end

  test "not_deleted scope should exclude categories with a deleted_at timestamp" do
    not_deleted_cat = categories(:category_technology) # This is not deleted
    deleted_cat = categories(:category_deleted)     # This is soft-deleted in fixtures

    not_deleted_scope = Category.not_deleted
    assert_includes not_deleted_scope, not_deleted_cat, "Scope should include category without deleted_at"
    assert_not_includes not_deleted_scope, deleted_cat, "Scope should exclude category with deleted_at"
  end

  # Enums
  test "should have correct enum values for status" do
    expected_statuses = { "active" => 0, "inactive" => 1 }
    assert_equal expected_statuses, Category.statuses, "Enum definition for status is incorrect"
  end

  test "should allow setting and querying status enum values" do
    category_for_enum_test = categories(:category_lifestyle) # Use a specific fixture
    category_for_enum_test.active!
    assert category_for_enum_test.active?, "Category should be in active status"

    category_for_enum_test.inactive!
    assert category_for_enum_test.inactive?, "Category should be in inactive status"
  end
end
