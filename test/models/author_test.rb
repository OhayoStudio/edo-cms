require "test_helper"

class AuthorTest < ActiveSupport::TestCase
  # Fixtures are automatically loaded.
  # Ensure articles fixture is available if testing dependent: :nullify or article_count
  fixtures :authors, :articles, :categories # categories needed for article creation

  setup do
    # Use authors(:one) as a base for tests that need an existing record.
    # Modifications inside a test usually don't persist due to transactions.
    @author = authors(:one) 
    # Ensure a known, valid state for @author if it's modified across multiple tests
    # or if tests depend on its initial fixture state.
    # For most validation tests, we'll be changing attributes and checking validity.
    
    # For uniqueness tests, ensure a second distinct author.
    @another_author = authors(:two)
    # Make sure emails are unique if they are not in fixtures, to avoid load-time errors.
    # This should ideally be handled by having valid, distinct fixtures.
    # If fixtures might have colliding data, adjust them or create fresh records in setup.
    unless @author.email != @another_author.email && @author.slug != @another_author.slug
      @author.update!(email: "author_one_test@example.com", slug: "author-one-test-slug")
      @another_author.update!(email: "author_two_test@example.com", slug: "author-two-test-slug")
    end
  end

  # Validations
  test "should be valid with all required attributes" do
    # Create a new author instance with minimal valid attributes
    valid_author = Author.new(
      first_name: "Test",
      last_name: "User",
      email: "test.user.#{Time.now.to_i}@example.com" # Ensure unique email
      # Slug will be auto-generated
    )
    assert valid_author.valid?, "Author should be valid. Errors: #{valid_author.errors.full_messages.join(", ")}"
  end

  test "should validate presence of first_name" do
    @author.first_name = nil
    assert_not @author.valid?, "Author should be invalid without a first_name"
    assert_includes @author.errors[:first_name], "can't be blank"
  end

  test "should validate presence of last_name" do
    @author.last_name = nil
    assert_not @author.valid?, "Author should be invalid without a last_name"
    assert_includes @author.errors[:last_name], "can't be blank"
  end

  test "should validate presence of email" do
    @author.email = nil
    assert_not @author.valid?, "Author should be invalid without an email"
    assert_includes @author.errors[:email], "can't be blank"
  end

  test "should validate uniqueness of email" do
    duplicate_author = Author.new(
      first_name: "Another",
      last_name: "Person",
      email: @author.email # Use existing author's email
    )
    assert_not duplicate_author.valid?, "Author with a duplicate email should be invalid"
    assert_includes duplicate_author.errors[:email], "has already been taken"
  end

  test "should validate format of email" do
    @author.email = "invalid_email_format"
    assert_not @author.valid?, "Author should be invalid with an incorrect email format"
    assert_includes @author.errors[:email], "is invalid"

    @author.email = "valid.email@example.com" # Reset to valid for subsequent checks if any
    assert @author.valid? # Assuming other fields are valid from setup or fixture
  end

  test "should validate presence of slug" do
    # Slug is normally generated. To test presence, bypass generation.
    @author.slug = nil
    assert_not @author.valid?, "Author should be invalid without a slug"
    assert_includes @author.errors[:slug], "can't be blank"
  end

  test "should validate uniqueness of slug" do
    duplicate_author = Author.new(
      first_name: "Unique",
      last_name: "Name",
      email: "unique.name.#{Time.now.to_i}@example.com", # Different email
      slug: @author.slug # Use existing author's slug
    )
    assert_not duplicate_author.valid?, "Author with a duplicate slug should be invalid"
    assert_includes duplicate_author.errors[:slug], "has already been taken"
  end

  test "should validate format of website if present" do
    @author.website = "invalid_website_url"
    assert_not @author.valid?, "Author should be invalid with an incorrect website URL format"
    assert_includes @author.errors[:website], "is invalid"

    @author.website = "http://example.com"
    assert @author.valid?, "Author should be valid with a correct website URL. Errors: #{@author.errors.full_messages.join(", ")}"

    @author.website = "" # Blank should be allowed
    assert @author.valid?, "Author should be valid with a blank website URL"

    @author.website = nil # Nil should be allowed
    assert @author.valid?, "Author should be valid with a nil website URL"
  end

  # Associations
  test "should have many articles" do
    assert_respond_to @author, :articles, "Author should respond to :articles"
  end

  test "should nullify author_id in articles when author is destroyed" do
    # Create a new author and article for this specific test to avoid side effects
    test_author = Author.create!(first_name: "Jane", last_name: "Doe", email: "jane.doe.#{Time.now.to_i}@example.com")
    # Ensure category fixture is valid for article creation
    category = categories(:one) 
    category.update!(name: "Category for Nullify Test", description: "Test desc") unless category.valid?
    
    article = test_author.articles.create!(
      title: "Test Article for Nullify", 
      category: category, 
      content: "Some content.", 
      status: :published, 
      published_at: Time.current
    )
    assert_not_nil article.author_id, "Article should initially have an author_id"
    
    test_author.destroy
    article.reload # Reload article from DB to see changes
    
    assert_nil article.author_id, "Article's author_id should be nullified after author destruction"
  end

  test "should have one attached avatar" do
    assert @author.respond_to?(:avatar), "Author should respond to :avatar"
    assert @author.avatar.respond_to?(:attach), "Author's avatar should support attachment"
    # To test actual attachment:
    # dummy_file_path = Rails.root.join('test', 'fixtures', 'files', 'dummy_avatar.png') # Create this file
    # @author.avatar.attach(io: File.open(dummy_file_path), filename: 'dummy_avatar.png', content_type: 'image/png')
    # assert @author.avatar.attached?, "Avatar should be attached"
  end

  # Callbacks
  test "should generate slug from full name when first_name or last_name changes" do
    author = Author.new(first_name: "New", last_name: "Author", email: "new.author.callback.#{Time.now.to_i}@example.com")
    author.valid? # Trigger before_validation callbacks (slug generation)
    assert_equal "new-author", author.slug, "Slug was not generated correctly for a new author"

    author.save!
    author.first_name = "BrandNew"
    author.valid? # Trigger slug regeneration
    assert_equal "brandnew-author", author.slug, "Slug did not update correctly when first_name changed"
  end

  test "should not generate new slug if full name has not changed" do
    author = Author.create!(first_name: "Stable", last_name: "Name", email: "stable.name.#{Time.now.to_i}@example.com")
    original_slug = author.slug
    
    author.bio = "An updated biography." # Change a non-name attribute
    author.valid? # Trigger callbacks
    author.save!
    
    assert_equal original_slug, author.slug, "Slug should not change if name attributes haven't changed"
  end

  # Scopes
  test "active scope should return only active authors" do
    Author.create!(first_name: "DefinitelyActive", last_name: "User", email: "def.active.#{Time.now.to_i}@example.com", status: :active)
    Author.create!(first_name: "DefinitelyInactive", last_name: "Person", email: "def.inactive.#{Time.now.to_i}@example.com", status: :inactive)

    active_authors_scope = Author.active
    active_authors_scope.each do |a|
      assert_equal "active", a.status, "Active scope should only return active authors"
    end
    assert_includes active_authors_scope.map(&:first_name), "DefinitelyActive"
    assert_not_includes active_authors_scope.map(&:first_name), "DefinitelyInactive"
  end

  test "not_deleted scope should exclude authors with deleted_at timestamp" do
    not_deleted_author = Author.create!(first_name: "NotDeleted", last_name: "Author", email: "not.deleted.#{Time.now.to_i}@example.com", deleted_at: nil)
    deleted_author = Author.create!(first_name: "IsDeleted", last_name: "Author", email: "is.deleted.#{Time.now.to_i}@example.com", deleted_at: Time.current)

    not_deleted_scope = Author.not_deleted
    assert_includes not_deleted_scope, not_deleted_author, "Scope should include not deleted author"
    assert_not_includes not_deleted_scope, deleted_author, "Scope should exclude deleted author"
  end

  # Enums
  test "should have correct enum values for status" do
    expected_statuses = %w[active inactive]
    assert_equal expected_statuses, Author.statuses.keys, "Enum keys for status are incorrect"
  end

  test "should allow setting and querying status enum values" do
    @author.active!
    assert @author.active?, "Author should be in active status"

    @author.inactive!
    assert @author.inactive?, "Author should be in inactive status"
  end

  test "should have correct enum values for role" do
    expected_roles = %w[writer editor admin]
    assert_equal expected_roles, Author.roles.keys, "Enum keys for role are incorrect"
  end

  test "should allow setting and querying role enum values" do
    @author.writer!
    assert @author.writer?, "Author's role should be writer"

    @author.editor!
    assert @author.editor?, "Author's role should be editor"

    @author.admin!
    assert @author.admin?, "Author's role should be admin"
  end

  # Methods
  test "full_name should return the concatenated first and last name" do
    @author.first_name = "John"
    @author.last_name = "Doe"
    assert_equal "John Doe", @author.full_name, "full_name method did not return expected result"
  end

  test "display_name should be an alias for full_name" do
    assert_equal @author.full_name, @author.display_name, "display_name should be the same as full_name"
  end

  test "soft_delete method should set deleted_at and change status to inactive" do
    # Ensure author is active and not deleted before test
    @author.update!(status: :active, deleted_at: nil)
    
    @author.soft_delete
    @author.reload # Reload from DB to confirm persistence of changes
    
    assert_not_nil @author.deleted_at, "deleted_at should be set after soft_delete"
    assert @author.inactive?, "Status should be inactive after soft_delete"
  end

  test "article_count method should return the count of published articles for the author" do
    author_for_count_test = Author.create!(first_name: "Counter", last_name: "Test", email: "counter.test.#{Time.now.to_i}@example.com")
    category = categories(:one) # Assuming this fixture exists and is valid
    
    # Create articles for this author
    author_for_count_test.articles.create!(title: "Published One", category: category, content: "Content", status: :published, published_at: Time.current)
    author_for_count_test.articles.create!(title: "Published Two", category: category, content: "Content", status: :published, published_at: Time.current)
    author_for_count_test.articles.create!(title: "Draft One", category: category, content: "Content", status: :draft)
    
    assert_equal 2, author_for_count_test.article_count, "article_count did not return correct number of published articles"
  end
end
