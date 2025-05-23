require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  # Fixtures are automatically loaded.
  # Ensure articles and authors fixtures are available if testing dependent: :nullify for articles.
  fixtures :categories, :articles, :authors

  setup do
    # Use categories(:one) as a base, ensuring its state is suitable for general tests.
    @category = categories(:one)
    # It's often better to create fresh, specific records in tests for uniqueness or callback tests
    # to avoid unintended interactions with fixture states or other tests.
    # For general validation tests, modifying a fixture instance is okay as transactions isolate tests.
    @category.update!(name: "Category One Test", description: "Description for category one test", slug: "category-one-test")

    @another_category = categories(:two)
    @another_category.update!(name: "Category Two Test", description: "Description for category two test", slug: "category-two-test")
  end

  # Validations
  test "should be valid with required attributes" do
    new_category = Category.new(name: "Valid New Category", description: "A valid description.")
    assert new_category.valid?, "Category should be valid. Errors: #{new_category.errors.full_messages.join(", ")}"
  end

  test "should validate presence of name" do
    @category.name = nil
    assert_not @category.valid?, "Category should be invalid without a name"
    assert_includes @category.errors[:name], "can't be blank"
  end

  test "should validate uniqueness of name" do
    duplicate_category = Category.new(name: @category.name, description: "Another description for duplicate name test.")
    assert_not duplicate_category.valid?, "Category with a duplicate name should be invalid"
    assert_includes duplicate_category.errors[:name], "has already been taken"
  end

  test "should validate presence of slug" do
    # Slug is normally generated. To test presence, bypass generation.
    @category.slug = nil
    assert_not @category.valid?, "Category should be invalid without a slug"
    assert_includes @category.errors[:slug], "can't be blank"
  end

  test "should validate uniqueness of slug" do
    duplicate_category = Category.new(
      name: "Unique Name For Slug Test #{Time.now.to_i}", # Ensure different name
      description: "Description for unique slug test.",
      slug: @category.slug # Use existing category's slug
    )
    assert_not duplicate_category.valid?, "Category with a duplicate slug should be invalid"
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
    parent_cat = Category.create!(name: "Parent Category Test", description: "Parent category description.")
    child_cat = Category.new(name: "Child Category Test", description: "Child category description.", parent: parent_cat)
    
    assert_equal parent_cat, child_cat.parent, "Child category's parent should be the assigned parent category"
    assert child_cat.save # Ensure it can be saved
  end

  test "should have many subcategories" do
    parent_cat_with_subs = Category.create!(name: "Parent With Subcategories Test", description: "Parent with subcategories description.")
    sub1 = parent_cat_with_subs.subcategories.create!(name: "Subcategory Test 1", description: "Subcategory 1 description.")
    sub2 = parent_cat_with_subs.subcategories.create!(name: "Subcategory Test 2", description: "Subcategory 2 description.")

    assert_includes parent_cat_with_subs.subcategories, sub1, "Parent should include subcategory 1"
    assert_includes parent_cat_with_subs.subcategories, sub2, "Parent should include subcategory 2"
  end

  test "should have many articles" do
    assert_respond_to @category, :articles, "Category should respond to :articles"
  end
  
  test "should nullify category_id in articles when category is destroyed" do
    category_for_nullify_test = Category.create!(name: "Nullify Test Category", description: "Category for testing nullify.")
    author_for_article = authors(:one) # Assuming this fixture exists and is valid
    
    article = category_for_nullify_test.articles.create!(
      title: "Article for Nullify Test", 
      author: author_for_article, 
      content: "Some content.", 
      status: :published, 
      published_at: Time.current
    )
    assert_not_nil article.category_id, "Article should initially have a category_id"
    
    category_for_nullify_test.destroy
    article.reload # Reload article from DB
    
    assert_nil article.category_id, "Article's category_id should be nullified after category destruction"
  end

  # Callbacks
  test "should generate slug from name when name changes" do
    category_for_slug_test = Category.new(name: "New Category For Slug Test", description: "Description for slug test.")
    category_for_slug_test.valid? # Trigger before_validation callbacks
    assert_equal "new-category-for-slug-test", category_for_slug_test.slug, "Slug was not generated correctly for a new category"

    category_for_slug_test.save!
    category_for_slug_test.name = "Updated Category For Slug Test"
    category_for_slug_test.valid? # Trigger slug regeneration
    assert_equal "updated-category-for-slug-test", category_for_slug_test.slug, "Slug did not update correctly when name changed"
  end

  test "should not generate new slug if name has not changed" do
    category_stable_slug = Category.create!(name: "Stable Slug Category", description: "Desc for stable slug.")
    original_slug = category_stable_slug.slug
    
    category_stable_slug.meta_title = "A new meta title." # Change a non-name attribute
    category_stable_slug.valid? # Trigger callbacks
    category_stable_slug.save!
    
    assert_equal original_slug, category_stable_slug.slug, "Slug should not change if name attribute hasn't changed"
  end

  # Scopes
  test "root_categories scope should return categories with no parent_id" do
    root_cat = Category.create!(name: "True Root Category", description: "Root category description.", parent_id: nil)
    child_of_root = Category.create!(name: "Child of True Root", description: "Child description.", parent: root_cat)

    root_categories_scope = Category.root_categories
    assert_includes root_categories_scope, root_cat, "Scope should include the root category"
    assert_not_includes root_categories_scope, child_of_root, "Scope should exclude child categories"
  end

  test "featured scope should return only featured categories" do
    featured_cat = Category.create!(name: "Definitely Featured Category", description: "Featured category description.", featured: true)
    non_featured_cat = Category.create!(name: "Definitely Not Featured Category", description: "Non-featured_category description.", featured: false)

    featured_categories_scope = Category.featured
    assert_includes featured_categories_scope, featured_cat, "Scope should include featured category"
    assert_not_includes featured_categories_scope, non_featured_cat, "Scope should exclude non-featured category"
  end

  test "active scope should return only active categories" do
    active_cat = Category.create!(name: "Clearly Active Category", description: "Active category description.", status: :active)
    inactive_cat = Category.create!(name: "Clearly Inactive Category", description: "Inactive category description.", status: :inactive)

    active_categories_scope = Category.active
    assert_includes active_categories_scope, active_cat, "Scope should include active category"
    assert_not_includes active_categories_scope, inactive_cat, "Scope should exclude inactive category"
  end

  test "not_deleted scope should exclude categories with a deleted_at timestamp" do
    not_deleted_cat = Category.create!(name: "Existing Category", description: "Not deleted category description.", deleted_at: nil)
    deleted_cat = Category.create!(name: "Soft Deleted Category", description: "Deleted category description.", deleted_at: Time.current)

    not_deleted_scope = Category.not_deleted
    assert_includes not_deleted_scope, not_deleted_cat, "Scope should include category without deleted_at"
    assert_not_includes not_deleted_scope, deleted_cat, "Scope should exclude category with deleted_at"
  end

  # Enums
  test "should have correct enum values for status" do
    # In Rails, Category.statuses returns a hash like {"active"=>0, "inactive"=>1}
    expected_statuses = { "active" => 0, "inactive" => 1 }
    assert_equal expected_statuses, Category.statuses, "Enum definition for status is incorrect"
  end

  test "should allow setting and querying status enum values" do
    @category.active!
    assert @category.active?, "Category should be in active status"

    @category.inactive!
    assert @category.inactive?, "Category should be in inactive status"
  end
end
