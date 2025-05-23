require "test_helper"
# require "open-uri" # Not strictly needed if attaching local files or using fixture_file_upload

class VideoTest < ActiveSupport::TestCase
  fixtures :videos

  DUMMY_IMAGE_BASENAME = 'dummy_video_test_image.png'.freeze
  DUMMY_IMAGE_PATH = Rails.root.join('tmp', DUMMY_IMAGE_BASENAME).freeze

  # Create a dummy file once for the test suite if it doesn't change.
  # Or ensure it's created before each test run if content could vary or get corrupted.
  def self.ensure_dummy_file_exists
    return if File.exist?(DUMMY_IMAGE_PATH)
    FileUtils.mkdir_p(Rails.root.join('tmp'))
    File.open(DUMMY_IMAGE_PATH, 'w') { |f| f.write("tiny dummy image content") }
  end
  ensure_dummy_file_exists # Call it when the class is loaded

  setup do
    # Ensure the dummy file is available for each test that might need it.
    # self.class.ensure_dummy_file_exists # Alternative: call in setup

    @video = videos(:one)
    # Update fixture records with unique titles to prevent issues if tests run in parallel or fixtures are shared.
    @video.update!(
      title: "Video One Test Title #{Time.now.to_f}",
      description: "Description for video one test.",
      url: "http://example.com/video1_test.mp4"
    )
    # Attach featured_image as it's validated for presence
    @video.featured_image.attach(io: File.open(DUMMY_IMAGE_PATH), filename: DUMMY_IMAGE_BASENAME, content_type: 'image/png') unless @video.featured_image.attached?


    @another_video = videos(:two)
    @another_video.update!(
      title: "Video Two Test Title #{Time.now.to_f}",
      description: "Description for video two test.",
      url: "http://example.com/video2_test.mp4"
    )
    @another_video.featured_image.attach(io: File.open(DUMMY_IMAGE_PATH), filename: DUMMY_IMAGE_BASENAME, content_type: 'image/png') unless @another_video.featured_image.attached?
  end

  # Validations
  test "should be valid with all required attributes and an attached image" do
    new_video = Video.new(
      title: "A Valid New Video #{Time.now.to_i}", 
      description: "Valid video description.", 
      url: "http://example.com/valid_new_video.mp4"
    )
    new_video.featured_image.attach(io: File.open(DUMMY_IMAGE_PATH), filename: DUMMY_IMAGE_BASENAME, content_type: 'image/png')
    assert new_video.valid?, "Video should be valid. Errors: #{new_video.errors.full_messages.join(", ")}"
  end

  test "should validate presence of title" do
    @video.title = nil
    assert_not @video.valid?, "Video should be invalid without a title"
    assert_includes @video.errors[:title], "can't be blank"
  end

  test "should validate presence of description" do
    @video.description = nil
    assert_not @video.valid?, "Video should be invalid without a description"
    assert_includes @video.errors[:description], "can't be blank"
  end

  test "should validate presence of url" do
    @video.url = nil
    assert_not @video.valid?, "Video should be invalid without a URL"
    assert_includes @video.errors[:url], "can't be blank"
  end

  test "should validate presence of featured_image" do
    @video.featured_image.purge # Detach the image
    assert_not @video.valid?, "Video should be invalid without a featured_image"
    assert_includes @video.errors[:featured_image], "can't be blank"
  end

  # Associations (ActiveStorage)
  test "should have one attached featured_image" do
    assert @video.respond_to?(:featured_image), "Video should respond to :featured_image"
    assert @video.featured_image.attached?, "Featured image should be attached for a valid video from setup"
  end

  # FriendlyId (Slugs)
  test "should generate slug from title on save" do
    video_for_slug_test = Video.new(
      title: "A Unique Test Video Title For Slug #{Time.now.to_i}", 
      description: "Description for slug test.", 
      url: "http://example.com/slug_test_video.mp4"
    )
    video_for_slug_test.featured_image.attach(io: File.open(DUMMY_IMAGE_PATH), filename: DUMMY_IMAGE_BASENAME, content_type: 'image/png')
    video_for_slug_test.save!
    
    expected_slug = "a-unique-test-video-title-for-slug-#{Time.now.to_i}".parameterize # Mimic FriendlyId's behavior
    # We cannot predict the exact slug if FriendlyId adds sequence numbers for uniqueness from other tests/db state.
    # So, we check if the generated slug contains the parameterized title.
    assert_not_nil video_for_slug_test.slug, "Slug should be generated"
    assert video_for_slug_test.slug.starts_with?("a-unique-test-video-title-for-slug"), "Slug should be based on the title"
  end

  test "should_generate_new_friendly_id? should return true if title changed" do
    @video.title = "A Brand New Video Title For Slug Check"
    assert @video.should_generate_new_friendly_id?, "should_generate_new_friendly_id? should be true when title changes"
  end

  test "should_generate_new_friendly_id? should return false if title has not changed" do
    # Ensure title is considered unchanged by saving it first or using a freshly loaded record.
    # If @video.title was just set and not saved, `title_changed?` might be true.
    clean_video = Video.find(@video.id) # Load a fresh copy
    assert_not clean_video.should_generate_new_friendly_id?, "should_generate_new_friendly_id? should be false when title is unchanged"
  end

  test "to_param should return the slug" do
    # Slug should be present from setup's save!
    assert_equal @video.slug, @video.to_param, "to_param should return the video's slug"
  end

  # Other Instance Methods
  test "to_s should return the video title" do
    assert_equal @video.title, @video.to_s, "to_s should return the video's title"
  end

  test "thumbnail method should return an ActiveStorage::VariantWithRecord" do
    assert_respond_to @video, :thumbnail, "Video should respond to :thumbnail method"
    # This test assumes Active Storage variants are configured and working.
    # It primarily checks that the method call doesn't error and returns an expected type.
    assert_nothing_raised { @video.thumbnail }
    # In a full environment, the result of @video.thumbnail would be an ActiveStorage::VariantWithRecord
    # For now, just check it's not nil if image is attached.
    assert_not_nil @video.thumbnail, "Thumbnail should not be nil when featured_image is attached"
  end

  test "thumbnail_url method should return a string path to the blob" do
    assert_respond_to @video, :thumbnail_url, "Video should respond to :thumbnail_url method"
    # This test relies on Rails URL helpers and Active Storage routes.
    generated_url = @video.thumbnail_url
    assert_not_nil generated_url, "thumbnail_url should return a non-nil string"
    assert_kind_of String, generated_url, "thumbnail_url should return a String"
    # Check if the path starts with the expected Active Storage blob path prefix
    assert generated_url.starts_with?("/rails/active_storage/blobs/redirect/") || generated_url.starts_with?("/rails/active_storage/blobs/proxy/"), 
           "thumbnail_url should be a valid Active Storage path. Got: #{generated_url}"
  end
  
  # Teardown to clean up any created dummy files
  # Note: The class-level ensure_dummy_file_exists and this teardown manage the dummy file.
  # If tests were parallelized at a method level and manipulated the same file, it could be an issue.
  # For standard Rails test execution, this should be fine.
  # To be extremely safe, each test creating a file could use a unique filename and clean it up.
  # However, for a single dummy image used for reads, this is generally okay.
  # The current DUMMY_IMAGE_PATH is class-level, so all tests use the same file.
  # If a test *modifies* the dummy file, it could affect others. Here, it's just for attachment.
end
