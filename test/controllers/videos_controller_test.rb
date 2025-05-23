require "test_helper"

class VideosControllerTest < ActionDispatch::IntegrationTest
  fixtures :videos, :stories # For checking story creation

  DUMMY_VIDEO_IMAGE_BASENAME = 'dummy_videos_controller_test_image.png'.freeze
  DUMMY_VIDEO_IMAGE_PATH = Rails.root.join('tmp', DUMMY_VIDEO_IMAGE_BASENAME).freeze

  def self.ensure_dummy_video_image_exists
    return if File.exist?(DUMMY_VIDEO_IMAGE_PATH)
    FileUtils.mkdir_p(Rails.root.join('tmp'))
    File.open(DUMMY_VIDEO_IMAGE_PATH, 'w') { |f| f.write("dummy image content for video controller test") }
  end
  ensure_dummy_video_image_exists

  setup do
    @video = videos(:one)
    @video.update!(
      title: "Video Controller Test One #{Time.now.to_f}",
      description: "Test description for video one in controller test",
      url: "http://example.com/video1_ctrl_test.mp4"
    )
    # Ensure featured_image is attached as it's validated for presence
    @video.featured_image.attach(io: File.open(DUMMY_VIDEO_IMAGE_PATH), filename: DUMMY_VIDEO_IMAGE_BASENAME, content_type: 'image/png') unless @video.featured_image.attached?

    # @other_video can be used if tests require a second distinct video instance
    # @other_video = videos(:two)
    # @other_video.update!(
    #   title: "Video Controller Test Two #{Time.now.to_f}",
    #   description: "Test description for video two in controller test",
    #   url: "http://example.com/video2_ctrl_test.mp4"
    # )
    # @other_video.featured_image.attach(io: File.open(DUMMY_VIDEO_IMAGE_PATH), filename: DUMMY_VIDEO_IMAGE_BASENAME, content_type: 'image/png') unless @other_video.featured_image.attached?
  end

  test "should get index and assign videos" do
    get videos_url
    assert_response :success
    assert_not_nil assigns(:videos), "@videos instance variable should be assigned"
  end

  test "should get new and assign a new video" do
    get new_video_url
    assert_response :success
    assert_instance_of Video, assigns(:video), "A new Video instance should be assigned"
    assert assigns(:video).new_record?, "Assigned @video should be a new record"
  end

  test "should create video and associated story with valid parameters" do
    video_params = {
      title: "New Created Video Controller Test #{Time.now.to_i}",
      description: "Description for the new video created via controller test.",
      url: "http://example.com/new_created_video_ctrl_test.mp4",
      featured_image: fixture_file_upload(DUMMY_VIDEO_IMAGE_PATH, 'image/png')
    }

    assert_difference("Video.count", 1, "Video count should increment by 1") do
      assert_difference("Story.count", 1, "Story count should increment by 1 as controller creates it") do
        post videos_url, params: { video: video_params }
      end
    end

    created_video = Video.last
    assert_redirected_to video_url(created_video), "Should redirect to the created video's show page"
    assert_equal "Video was successfully created.", flash[:notice], "Flash notice for creation should be set"
    assert_equal video_params[:title], created_video.title
    assert created_video.featured_image.attached?, "Featured image should be attached to the created video"

    story = Story.find_by(storyable: created_video)
    assert_not_nil story, "A Story should be created for the new video"
    assert_equal created_video.slug, story.slug, "Story slug should match video slug"
    assert story.is_published, "Story should be marked as published by the controller logic"
    # The controller sets published_at: Time.now, so we check for recent time.
    assert_in_delta Time.now, story.published_at, 5.seconds, "Story published_at should be set to current time"
  end

  test "should show video and assign it" do
    get video_url(@video)
    assert_response :success
    assert_equal @video, assigns(:video), "@video instance variable should be assigned correctly"
  end
  
  test "should show video using its slug (FriendlyId)" do
    get video_url(id: @video.slug) # Rails uses to_param, which is slug for FriendlyId models
    assert_response :success
    assert_equal @video, assigns(:video), "Should find video by slug and assign it"
  end

  test "should get edit for a video and assign it" do
    get edit_video_url(@video)
    assert_response :success
    assert_equal @video, assigns(:video), "@video instance variable should be assigned for edit"
  end

  test "should update video with valid parameters" do
    updated_title = "Updated Video Title Controller Test #{Time.now.to_i}"
    patch video_url(@video), params: { 
      video: { 
        title: updated_title, 
        description: "Updated video description from controller test."
        # To test featured_image update, provide a new fixture_file_upload here
      } 
    }
    assert_redirected_to video_url(@video), "Should redirect to the video's show page after update"
    @video.reload
    
    assert_equal updated_title, @video.title, "Video title should be updated"
    assert_equal "Updated video description from controller test.", @video.description, "Video description should be updated"
    assert_equal "Video was successfully updated.", flash[:notice], "Flash notice for update should be set"
  end

  test "should destroy video and its associated story" do
    # Create a video and its story specifically for this test to ensure clean state
    video_to_delete = Video.create!(
      title: "Video for Deletion Controller Test #{Time.now.to_i}", 
      description: "This video will be deleted.", 
      url: "http://example.com/to_be_deleted_video.mp4"
    )
    video_to_delete.featured_image.attach(io: File.open(DUMMY_VIDEO_IMAGE_PATH), filename: DUMMY_VIDEO_IMAGE_BASENAME, content_type: 'image/png')
    
    # VideosController#create makes a Story. Assume VideosController#destroy should handle it or model has dependent: :destroy.
    # If Video model has `has_one :story, as: :storyable, dependent: :destroy` (or similar for has_many)
    # then Story.count will change. Otherwise, it won't.
    # For this test, let's assume the Story IS deleted with the Video.
    # If this fails, it means the `dependent: :destroy` is missing in the Video model's association to Story.
    Story.create!(storyable: video_to_delete, slug: video_to_delete.slug, is_published: true, published_at: Time.current)

    assert_difference("Video.count", -1, "Video count should decrease by 1") do
      assert_difference("Story.count", -1, "Story count should decrease by 1 if dependent destroy is set up") do
        delete video_url(video_to_delete)
      end
    end

    assert_redirected_to videos_url, "Should redirect to videos index page after destruction"
    assert_equal "Video was successfully destroyed.", flash[:notice], "Flash notice for destruction should be set"
  end

  test "should not create video with invalid parameters (e.g., blank title)" do
    assert_no_difference(["Video.count", "Story.count"], "Video and Story counts should not change with invalid params") do
      post videos_url, params: { 
        video: { 
          title: "", # Invalid: title is blank
          description: "Description for invalid video", 
          url: "http://example.com/invalid_video.mp4",
          featured_image: fixture_file_upload(DUMMY_VIDEO_IMAGE_PATH, 'image/png')
        } 
      }
    end
    assert_response :unprocessable_entity, "Response should be :unprocessable_entity for invalid create params"
    assert_template :new, "Should re-render the 'new' template"
  end
  
  test "should not create video with invalid parameters (e.g., missing featured_image)" do
    assert_no_difference(["Video.count", "Story.count"], "Video and Story counts should not change if featured_image is missing") do
      post videos_url, params: { 
        video: { 
          title: "Video Without Required Image #{Time.now.to_i}", 
          description: "Description for video missing image", 
          url: "http://example.com/video_no_image.mp4"
          # featured_image is missing, which is a required param
        } 
      }
    end
    assert_response :unprocessable_entity, "Response should be :unprocessable_entity when featured_image is missing"
    assert_template :new, "Should re-render the 'new' template"
  end

  test "should not update video with invalid parameters (e.g., blank title)" do
    original_title = @video.title
    patch video_url(@video), params: { video: { title: "" } } # Invalid: title is blank
    assert_response :unprocessable_entity, "Response should be :unprocessable_entity for invalid update params"
    assert_template :edit, "Should re-render the 'edit' template"
    @video.reload
    assert_equal original_title, @video.title, "Video title should not change with invalid update params"
  end
  
  def self.cleanup_dummy_video_image
    FileUtils.rm_f(DUMMY_VIDEO_IMAGE_PATH) if File.exist?(DUMMY_VIDEO_IMAGE_PATH)
  end
  Minitest.after_run { cleanup_dummy_video_image }
end
