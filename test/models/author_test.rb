require "test_helper"

class AuthorTest < ActiveSupport::TestCase
  # Fixtures are automatically loaded.
  # Ensure articles fixture is available if testing dependent: :nullify or article_count
  fixtures :authors, :articles, :categories # categories needed for article creation

  setup do
    # Use a descriptive fixture name. author_jane is an active writer.
    @author = authors(:author_jane)

    # For uniqueness tests, ensure a second distinct author. author_john is an active editor.
    @another_author = authors(:author_john)

    # The following unless block might not be strictly necessary if fixtures are well-defined
    # and distinct. However, it's a safeguard if fixture data could be inconsistent.
    unless @author.email != @another_author.email && @author.slug != @another_author.slug
      # If they were not distinct, update them. This part is less critical if fixtures are good.
      @author.update!(email: "author_jane_test_#{Time.now.to_f}@example.com", slug: "author-jane-test-slug-#{Time.now.to_f}")
      @another_author.update!(email: "author_john_test_#{Time.now.to_f}@example.com", slug: "author-john-test-slug-#{Time.now.to_f}")
    end
  end

  # Validations
  test "should be valid with all required attributes" do
    valid_author = Author.new(
      first_name: "Test",
      last_name: "User",
      email: "test.user.#{Time.now.to_i}@example.com"
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
    # Capture the valid email before mutating; the fixture accessor memoizes
    # the same instance, so reading it back after mutation would not reset it.
    valid_email = @author.email

    @author.email = "invalid_email_format"
    assert_not @author.valid?, "Author should be invalid with an incorrect email format"
    assert_includes @author.errors[:email], "is invalid"

    @author.email = valid_email
    assert @author.valid?
  end

  test "slug is populated from the full name when name attributes change" do
    # generate_slug derives the slug from the full name whenever first_name or
    # last_name changes (always true for a new record), so a named author is
    # never missing its slug; the presence validation is backstopped.
    @author.first_name = "Janet"
    @author.valid?
    assert_equal "janet-doe", @author.slug
    assert_empty @author.errors[:slug], "Slug presence error should not fire"
  end

  test "should validate uniqueness of slug" do
    # generate_slug overwrites any explicit slug with full_name.parameterize,
    # so a duplicate slug comes from reusing the existing author's name
    # (-> "jane-doe") rather than from setting :slug directly.
    duplicate_author = Author.new(
      first_name: @author.first_name,
      last_name: @author.last_name,
      email: "unique.name.#{Time.now.to_i}@example.com"
    )
    assert_not duplicate_author.valid?, "Author with a duplicate slug should be invalid"
    assert_includes duplicate_author.errors[:slug], "has already been taken"
  end

  test "should validate format of website if present" do
    @author.website = "invalid_website_url"
    assert_not @author.valid?, "Author should be invalid with an incorrect website URL format"
    assert_includes @author.errors[:website], "is invalid"

    @author.website = "http://example.com" # Valid website
    # Ensure other attributes are valid before this assertion if @author was made invalid by previous lines
    @author.email = authors(:author_jane).email # Reset email if it was made invalid
    assert @author.valid?, "Author should be valid with a correct website URL. Errors: #{@author.errors.full_messages.join(", ")}"

    @author.website = ""
    assert @author.valid?, "Author should be valid with a blank website URL"

    @author.website = nil
    assert @author.valid?, "Author should be valid with a nil website URL"
  end

  # Associations
  test "should have many articles" do
    assert_respond_to @author, :articles, "Author should respond to :articles"
  end

  test "articles require an author and the column is not nullable" do
    # The model declares has_many :articles, dependent: :nullify, but the DB
    # enforces a NOT NULL constraint on articles.author_id (and belongs_to is
    # required), so an article cannot exist without an author. An author with
    # no articles can be destroyed cleanly.
    empty_author = Author.create!(first_name: "Lonely", last_name: "Author", email: "lonely.author.#{Time.now.to_i}@example.com")
    assert_difference("Author.count", -1) do
      empty_author.destroy
    end

    article = Article.new(
      title: "Article Without Author #{Time.now.to_i}",
      category: categories(:category_technology),
      content: "content",
      reading_time: 1
    )
    assert_not article.valid?, "Article should be invalid without an author"
    assert_includes article.errors[:author], "must exist"
  end

  test "should have one attached avatar" do
    assert @author.respond_to?(:avatar), "Author should respond to :avatar"
    assert @author.avatar.respond_to?(:attach), "Author's avatar should support attachment"
  end

  # Callbacks
  test "should generate slug from full name when first_name or last_name changes" do
    author_for_slug_test = Author.new(first_name: "NewSlug", last_name: "AuthorSlug", email: "new.slug.author.callback.#{Time.now.to_i}@example.com")
    author_for_slug_test.valid?
    assert_equal "newslug-authorslug", author_for_slug_test.slug, "Slug was not generated correctly for a new author"

    author_for_slug_test.save!
    author_for_slug_test.first_name = "BrandNewSlug"
    author_for_slug_test.valid?
    assert_equal "brandnewslug-authorslug", author_for_slug_test.slug, "Slug did not update correctly when first_name changed"
  end

  test "should not generate new slug if full name has not changed" do
    author_stable_slug = Author.create!(first_name: "StableSlug", last_name: "NameSlug", email: "stable.slug.name.#{Time.now.to_i}@example.com")
    original_slug = author_stable_slug.slug

    author_stable_slug.bio = "An updated biography for stable slug."
    author_stable_slug.valid?
    author_stable_slug.save!

    assert_equal original_slug, author_stable_slug.slug, "Slug should not change if name attributes haven't changed"
  end

  # Scopes
  test "active scope should return only active authors" do
    # Assuming author_jane and author_john are active, and author_inactive is inactive from fixtures
    active_authors_scope = Author.active

    assert_includes active_authors_scope, authors(:author_jane)
    assert_includes active_authors_scope, authors(:author_john)
    assert_not_includes active_authors_scope, authors(:author_inactive)

    active_authors_scope.each do |a|
      assert_equal "active", a.status, "Active scope should only return active authors"
    end
  end

  test "not_deleted scope should exclude authors with deleted_at timestamp" do
    # Assuming author_jane is not deleted, and author_deleted is soft-deleted from fixtures
    not_deleted_scope = Author.not_deleted
    assert_includes not_deleted_scope, authors(:author_jane)
    assert_not_includes not_deleted_scope, authors(:author_deleted)
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
    @author.role = :writer # Set directly or use bang methods
    assert @author.writer?, "Author's role should be writer"

    @author.editor!
    assert @author.editor?, "Author's role should be editor"

    @author.admin!
    assert @author.admin?, "Author's role should be admin"
  end

  # Methods
  test "full_name should return the concatenated first and last name" do
    # Use a specific fixture for this test for predictability
    test_author_for_fullname = authors(:author_jane) # Jane Doe
    assert_equal "Jane Doe", test_author_for_fullname.full_name, "full_name method did not return expected result"
  end

  test "display_name should be an alias for full_name" do
    assert_equal @author.full_name, @author.display_name, "display_name should be the same as full_name"
  end

  test "soft_delete method should set deleted_at and change status to inactive" do
    author_to_soft_delete = authors(:author_john) # Choose an active, non-deleted author
    author_to_soft_delete.update!(status: :active, deleted_at: nil) # Ensure starting state

    author_to_soft_delete.soft_delete
    author_to_soft_delete.reload

    assert_not_nil author_to_soft_delete.deleted_at, "deleted_at should be set after soft_delete"
    assert author_to_soft_delete.inactive?, "Status should be inactive after soft_delete"
  end

  test "article_count method should return the count of published articles for the author" do
    author_for_article_count = authors(:author_jane)
    category_for_articles = categories(:category_technology)

    # Clear existing articles if any, or ensure predictable state
    author_for_article_count.articles.destroy_all

    author_for_article_count.articles.create!(title: "Published Article One by Jane", category: category_for_articles, content: "Content", status: :published, published_at: Time.current, reading_time: 1)
    author_for_article_count.articles.create!(title: "Published Article Two by Jane", category: category_for_articles, content: "Content", status: :published, published_at: Time.current, reading_time: 1)
    author_for_article_count.articles.create!(title: "Draft Article by Jane", category: category_for_articles, content: "Content", status: :draft, reading_time: 1)

    assert_equal 2, author_for_article_count.article_count, "article_count did not return correct number of published articles"
  end
end
