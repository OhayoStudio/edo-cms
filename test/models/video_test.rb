require "test_helper"
# require "open-uri" # Not strictly needed if attaching local files or using fixture_file_upload

class VideoTest < ActiveSupport::TestCase
  fixtures :videos

  DUMMY_IMAGE_BASENAME = "dummy_video_test_image.png".freeze
  DUMMY_IMAGE_PATH = Rails.root.join("tmp", DUMMY_IMAGE_BASENAME).freeze

  def self.ensure_dummy_file_exists
    return if File.exist?(DUMMY_IMAGE_PATH)
    FileUtils.mkdir_p(Rails.root.join("tmp"))
    File.open(DUMMY_IMAGE_PATH, "w") { |f| f.write("tiny dummy image content") }
  end
  ensure_dummy_file_exists

  setup do
    @video = videos(:video_intro_rails) # Using descriptive fixture name
    # Ensure the fixture has necessary attributes for tests, e.g., an attached image.
    # The fixture itself should ideally define these, but setup can enforce.
    @video.featured_image.attach(io: File.open(DUMMY_IMAGE_PATH), filename: DUMMY_IMAGE_BASENAME, content_type: "image/png") unless @video.featured_image.attached?
    # Ensure slug is present if tests rely on it and it's not guaranteed by fixture save
    @video.save! if @video.changed? || @video.slug.blank?


    @another_video = videos(:video_api_design) # Using another descriptive fixture name
    @another_video.featured_image.attach(io: File.open(DUMMY_IMAGE_PATH), filename: DUMMY_IMAGE_BASENAME, content_type: "image/png") unless @another_video.featured_image.attached?
    @another_video.save! if @another_video.changed? || @another_video.slug.blank?
  end

  # Validations
  test "should be valid with all required attributes and an attached image" do
    new_video = Video.new(
      title: "A Valid New Video #{Time.now.to_i}",
      description: "Valid video description.",
      url: "http://example.com/valid_new_video.mp4"
    )
    new_video.featured_image.attach(io: File.open(DUMMY_IMAGE_PATH), filename: DUMMY_IMAGE_BASENAME, content_type: "image/png")
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
    @video.featured_image.purge
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
    video_for_slug_test.featured_image.attach(io: File.open(DUMMY_IMAGE_PATH), filename: DUMMY_IMAGE_BASENAME, content_type: "image/png")
    video_for_slug_test.save!

    expected_slug_prefix = "a-unique-test-video-title-for-slug" # Prefix of the parameterized title
    assert_not_nil video_for_slug_test.slug, "Slug should be generated"
    assert video_for_slug_test.slug.starts_with?(expected_slug_prefix), "Slug ('#{video_for_slug_test.slug}') should be based on the title ('#{video_for_slug_test.title}')"
  end

  test "should_generate_new_friendly_id? should return true if title changed" do
    @video.title = "A Brand New Video Title For Slug Check #{Time.now.to_i}" # Ensure it's actually different
    assert @video.should_generate_new_friendly_id?, "should_generate_new_friendly_id? should be true when title changes"
  end

  test "should_generate_new_friendly_id? should return false if title has not changed" do
    # Load a fresh copy to ensure `title_changed?` is false.
    clean_video = Video.find(@video.id)
    assert_not clean_video.should_generate_new_friendly_id?, "should_generate_new_friendly_id? should be false when title is unchanged"
  end

  test "to_param should return the slug" do
    assert_not_nil @video.slug, "Slug should be present for to_param test"
    assert_equal @video.slug, @video.to_param, "to_param should return the video's slug"
  end

  # Other Instance Methods
  test "to_s should return the video title" do
    assert_equal @video.title, @video.to_s, "to_s should return the video's title"
  end

  test "thumbnail method should return an ActiveStorage::VariantWithRecord" do
    assert @video.featured_image.attached?, "Featured image must be attached for thumbnail test"
    assert_respond_to @video, :thumbnail, "Video should respond to :thumbnail method"
    assert_nothing_raised { @video.thumbnail }
    assert_not_nil @video.thumbnail, "Thumbnail should not be nil when featured_image is attached"
    # In a full environment, you might also check:
    # assert_instance_of ActiveStorage::VariantWithRecord, @video.thumbnail
  end

  test "thumbnail_url method should return a string path to the blob" do
    assert @video.featured_image.attached?, "Featured image must be attached for thumbnail_url test"
    assert_respond_to @video, :thumbnail_url, "Video should respond to :thumbnail_url method"
    generated_url = @video.thumbnail_url
    assert_not_nil generated_url, "thumbnail_url should return a non-nil string"
    assert_kind_of String, generated_url, "thumbnail_url should return a String"
    assert generated_url.starts_with?("/rails/active_storage/blobs/redirect/") || generated_url.starts_with?("/rails/active_storage/blobs/proxy/"),
           "thumbnail_url ('#{generated_url}') should be a valid Active Storage path."
  end

  def self.cleanup_dummy_image
    FileUtils.rm_f(DUMMY_IMAGE_PATH) if File.exist?(DUMMY_IMAGE_PATH)
  end
  Minitest.after_run { cleanup_dummy_image }
end
