require "test_helper"

class StoriesControllerTest < ActionDispatch::IntegrationTest
  fixtures :stories, :articles, :videos, :authors, :categories

  DUMMY_VIDEO_FEATURE_IMAGE_BASENAME = 'dummy_stories_ctrl_video_feature.png'.freeze
  DUMMY_VIDEO_FEATURE_IMAGE_PATH = Rails.root.join('tmp', DUMMY_VIDEO_FEATURE_IMAGE_BASENAME).freeze

  def self.ensure_dummy_video_feature_image_exists
    return if File.exist?(DUMMY_VIDEO_FEATURE_IMAGE_PATH)
    FileUtils.mkdir_p(Rails.root.join('tmp'))
    File.open(DUMMY_VIDEO_FEATURE_IMAGE_PATH, 'w') { |f| f.write("dummy video feature image for stories controller test") }
  end
  ensure_dummy_video_feature_image_exists

  setup do
    # Use descriptive fixture names for authors and categories
    @author = authors(:author_jane) 
    @category1 = categories(:category_technology)
    @category2 = categories(:category_lifestyle)

    # Use descriptive fixture names for storyables (articles and videos)
    @article1 = articles(:article_published_tech) 
    @article2 = articles(:article_draft_lifestyle) # This one is a draft, will be used for an unpublished story
    @video1 = videos(:video_intro_rails)
    
    # Ensure storyables have correct associations if not set by fixtures (though good fixtures should handle this)
    @article1.update!(author: @author, category: @category1) unless @article1.author == @author && @article1.category == @category1
    @article2.update!(author: @author, category: @category2) unless @article2.author == @author && @article2.category == @category2
    @video1.featured_image.attach(io: File.open(DUMMY_VIDEO_FEATURE_IMAGE_PATH), filename: DUMMY_VIDEO_FEATURE_IMAGE_BASENAME, content_type: 'image/png') unless @video1.featured_image.attached?


    # Use descriptive story fixtures.
    # Note: The previous Story.destroy_all was removed. Assuming fixtures are now the source of truth.
    # If specific stories are needed that aren't in fixtures, create them here.
    @story_article1_top = stories(:story_for_article_published_tech) # This story is for @article1, is_top: true
    @story_article2_recent_published_from_fixture = stories(:story_for_video_api_design) # Example, choose relevant published story
    @story_video1_recent_published_from_fixture = stories(:story_for_video_intro_rails) # Example

    @story_unpublished = stories(:story_for_article_draft_lifestyle) # This story is for @article2 (draft)
    
    @story_for_actions = @story_article1_top # Default story for show, edit, update, destroy tests
  end

  test "should get index and assign correct stories and videos" do
    get stories_url
    assert_response :success

    assert_equal @story_article1_top, assigns(:top_story), "Incorrect top story assigned"
    
    assert_not_nil assigns(:recent_stories), "@recent_stories should be assigned"
    # Adjust assertions based on actual fixture data for recent stories
    # Example: if story_for_video_api_design and story_for_video_intro_rails are the next most recent (excluding top)
    expected_recent_stories = [stories(:story_for_video_api_design), stories(:story_for_video_intro_rails)]
                                .sort_by(&:published_at).reverse.first(4) # Ensure we take up to 4, ordered
    
    assigns(:recent_stories).each_with_index do |assigned_story, index|
      break if index >= expected_recent_stories.length # Compare only up to the number of expected stories
      assert_equal expected_recent_stories[index].id, assigned_story.id, "Recent story at index #{index} is not as expected or not correctly ordered"
    end
    assert_not_includes assigns(:recent_stories).map(&:id), @story_article1_top.id, "Top story should be excluded from recent stories list"
    assert_not_includes assigns(:recent_stories).map(&:id), @story_unpublished.id, "Unpublished stories should be excluded from recent stories"


    assert_not_nil assigns(:videos), "@videos should be assigned"
    # video_intro_rails is a fixture. Ensure it's among the limited videos.
    assert_includes assigns(:videos).map(&:id), videos(:video_intro_rails).id, "Videos list should include a known video"

    assert_not_nil assigns(:latest_stories_by_category), "@latest_stories_by_category should be assigned"
    # Check if stories from categories are present, e.g. story_for_article_published_tech is for category_technology
    assert_includes assigns(:latest_stories_by_category).map(&:id), @story_article1_top.id
    # Add more checks based on your fixture setup for latest_stories_by_category
    category_ids_in_latest = assigns(:latest_stories_by_category).map { |s| s.storyable.category_id }.uniq
    assert_equal category_ids_in_latest.count, assigns(:latest_stories_by_category).count, "Should be only one latest story per category"
  end

  test "should get new and assign a new story" do
    get new_story_url
    assert_response :success
    assert_instance_of Story, assigns(:story), "A new Story instance should be assigned"
    assert assigns(:story).new_record?, "Assigned @story should be a new record"
  end

  test "should create story for an Article storyable" do
    # Use a specific article fixture for creating a new story
    new_article_for_story = articles(:article_review_general) 
    story_params = {
      storyable_id: new_article_for_story.id,
      storyable_type: "Article",
      slug: "newly-created-story-for-article-#{Time.now.to_i}", # Ensure unique slug for test
      is_published: true,
      published_at: Time.current,
      is_top: false
    }

    assert_difference("Story.count", 1, "Story count should increment by 1") do
      post stories_url, params: { story: story_params }
    end

    created_story = Story.last
    assert_redirected_to story_url(created_story), "Should redirect to the created story's show page"
    assert_equal "Story was successfully created.", flash[:notice], "Flash notice for creation should be set"
    assert_equal new_article_for_story, created_story.storyable, "Created story's storyable should be the new article"
  end

  test "should show story and assign it" do
    get story_url(@story_for_actions) # @story_for_actions is stories(:story_for_article_published_tech)
    assert_response :success
    assert_equal @story_for_actions, assigns(:story), "@story instance variable should be assigned correctly"
  end

  test "should get edit for a story and assign it" do
    get edit_story_url(@story_for_actions)
    assert_response :success
    assert_equal @story_for_actions, assigns(:story), "@story instance variable should be assigned for edit"
  end

  test "should update story with valid parameters" do
    story_to_update = stories(:story_for_video_api_design) # Use a specific story fixture
    new_slug_for_update = "updated-story-slug-ctrl-#{Time.now.to_i}"
    updated_params = {
      is_published: false,
      published_at: Time.current + 2.days, 
      slug: new_slug_for_update
    }
    patch story_url(story_to_update), params: { story: updated_params }
    assert_redirected_to story_url(story_to_update), "Should redirect to the story's show page after update"
    
    story_to_update.reload
    assert_equal false, story_to_update.is_published, "Story's is_published status should be updated"
    assert_in_delta (Time.current + 2.days), story_to_update.published_at, 1.second, "Story's published_at should be updated"
    assert_equal new_slug_for_update, story_to_update.slug, "Story's slug should be updated"
    assert_equal "Story was successfully updated.", flash[:notice], "Flash notice for update should be set"
  end

  test "should destroy story" do
    # Use a specific story that can be destroyed, e.g., one not used in other assertions or setup logic.
    story_to_be_destroyed = stories(:story_scheduled_article) 
    
    assert_difference("Story.count", -1, "Story count should decrease by 1") do
      delete story_url(story_to_be_destroyed)
    end

    assert_redirected_to stories_url, "Should redirect to stories index page after destruction"
    assert_equal "Story was successfully destroyed.", flash[:notice], "Flash notice for destruction should be set"
  end
  
  def self.cleanup_dummy_video_feature_image
    FileUtils.rm_f(DUMMY_VIDEO_FEATURE_IMAGE_PATH) if File.exist?(DUMMY_VIDEO_FEATURE_IMAGE_PATH)
  end
  Minitest.after_run { cleanup_dummy_video_feature_image }
end
