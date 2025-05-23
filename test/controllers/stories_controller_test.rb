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
    # It's important to set up distinct, valid records for associations.
    @author = authors(:one)
    @author.update!(email: "stories_ctrl_author_#{Time.now.to_f}@example.com") # Ensure unique email

    @category1 = categories(:one)
    @category1.update!(name: "Stories Category One #{Time.now.to_f}", description: "Desc cat one stories")

    @category2 = categories(:two)
    @category2.update!(name: "Stories Category Two #{Time.now.to_f}", description: "Desc cat two stories")

    # Create fresh storyable items for tests
    @article1 = Article.create!(title: "Article Story 1 #{Time.now.to_f}", author: @author, category: @category1, content: "content for story test", status: :published, published_at: Time.current - 1.day, featured: true)
    @article2 = Article.create!(title: "Article Story 2 #{Time.now.to_f}", author: @author, category: @category2, content: "content for story test", status: :published, published_at: Time.current - 2.days)
    
    @video1 = Video.create!(title: "Video Story 1 #{Time.now.to_f}", description: "desc for video story", url: "http://example.com/video1_story_test.mp4")
    @video1.featured_image.attach(io: File.open(DUMMY_VIDEO_FEATURE_IMAGE_PATH), filename: DUMMY_VIDEO_FEATURE_IMAGE_BASENAME, content_type: 'image/png') unless @video1.featured_image.attached?
    
    # Clean up existing stories from fixtures to prevent interference with specific counts and logic.
    Story.destroy_all 

    # Create specific stories for testing different scenarios
    @story_article1_top = Story.create!(storyable: @article1, slug: @article1.slug, is_published: true, published_at: @article1.published_at, is_top: true)
    @story_article2_recent = Story.create!(storyable: @article2, slug: @article2.slug, is_published: true, published_at: @article2.published_at, is_top: false)
    @story_video1_recent = Story.create!(storyable: @video1, slug: @video1.slug, is_published: true, published_at: Time.current - 3.days, is_top: false)
    
    unpublished_article = Article.create!(title: "Unpublished Article for Story Test #{Time.now.to_f}", author: @author, category: @category1, content: "content", status: :draft)
    @story_unpublished = Story.create!(storyable: unpublished_article, slug: unpublished_article.slug, is_published: false, published_at: Time.current)
    
    @story_for_actions = @story_article1_top # Default story for show, edit, update, destroy tests
  end

  test "should get index and assign correct stories and videos" do
    get stories_url
    assert_response :success

    assert_equal @story_article1_top, assigns(:top_story), "Incorrect top story assigned"
    
    assert_not_nil assigns(:recent_stories), "@recent_stories should be assigned"
    # Expected recent (excluding top): @story_article2_recent, @story_video1_recent (ordered by published_at desc)
    expected_recent_ids = [@story_article2_recent, @story_video1_recent].sort_by(&:published_at).reverse.map(&:id)
    actual_recent_ids = assigns(:recent_stories).map(&:id)
    assert_equal expected_recent_ids, actual_recent_ids, "Recent stories are not as expected or not correctly ordered"
    assert_not_includes assigns(:recent_stories), @story_article1_top, "Top story should be excluded from recent stories list"
    assert_not_includes assigns(:recent_stories).map(&:id), @story_unpublished.id, "Unpublished stories should be excluded from recent stories"

    assert_not_nil assigns(:videos), "@videos should be assigned"
    assert_includes assigns(:videos), @video1, "Videos list should include created video"

    assert_not_nil assigns(:latest_stories_by_category), "@latest_stories_by_category should be assigned"
    # @story_article1_top is in @category1, @story_article2_recent is in @category2. Both should be latest for their cat.
    assert_includes assigns(:latest_stories_by_category).map(&:id), @story_article1_top.id
    assert_includes assigns(:latest_stories_by_category).map(&:id), @story_article2_recent.id
    category_ids_in_latest = assigns(:latest_stories_by_category).map { |s| s.storyable.category_id }
    assert_equal category_ids_in_latest.uniq.count, category_ids_in_latest.count, "Should be only one latest story per category"
  end

  test "should get new and assign a new story" do
    get new_story_url
    assert_response :success
    assert_instance_of Story, assigns(:story), "A new Story instance should be assigned"
    assert assigns(:story).new_record?, "Assigned @story should be a new record"
  end

  test "should create story for an Article storyable" do
    new_article_for_story = Article.create!(title: "Article for New Story Create Test #{Time.now.to_i}", author: @author, category: @category1, content: "content", status: :published, published_at: Time.current)
    story_params = {
      storyable_id: new_article_for_story.id,
      storyable_type: "Article",
      slug: new_article_for_story.slug,
      is_published: true,
      published_at: new_article_for_story.published_at,
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
    get story_url(@story_for_actions)
    assert_response :success
    assert_equal @story_for_actions, assigns(:story), "@story instance variable should be assigned correctly"
  end

  test "should get edit for a story and assign it" do
    get edit_story_url(@story_for_actions)
    assert_response :success
    assert_equal @story_for_actions, assigns(:story), "@story instance variable should be assigned for edit"
  end

  test "should update story with valid parameters" do
    new_slug_for_update = "updated-story-slug-#{Time.now.to_i}"
    updated_params = {
      is_published: false,
      published_at: Time.current + 2.days, # Future date
      slug: new_slug_for_update
    }
    patch story_url(@story_for_actions), params: { story: updated_params }
    assert_redirected_to story_url(@story_for_actions), "Should redirect to the story's show page after update"
    
    @story_for_actions.reload
    assert_equal false, @story_for_actions.is_published, "Story's is_published status should be updated"
    assert_in_delta (Time.current + 2.days), @story_for_actions.published_at, 1.second, "Story's published_at should be updated"
    assert_equal new_slug_for_update, @story_for_actions.slug, "Story's slug should be updated"
    assert_equal "Story was successfully updated.", flash[:notice], "Flash notice for update should be set"
  end

  test "should destroy story" do
    story_to_be_destroyed = Story.create!(storyable: @article1, slug: "story-to-destroy-#{Time.now.to_i}", is_published: true, published_at: Time.current)
    
    assert_difference("Story.count", -1, "Story count should decrease by 1") do
      delete story_url(story_to_be_destroyed)
    end

    assert_redirected_to stories_url, "Should redirect to stories index page after destruction"
    assert_equal "Story was successfully destroyed.", flash[:notice], "Flash notice for destruction should be set"
  end
  
  # The controller uses `params.expect`, which raises ActionController::ParameterMissing if keys are missing.
  # Thus, testing "invalid params" by omitting keys is not straightforward for the `else` branch of `save`.
  # A model-level validation failure would be needed to test that branch properly.
  # test "should not create story if storyable is invalid or save fails" do
  #   # This requires model validations on Story or mocking story.save to return false.
  # end

  def self.cleanup_dummy_video_feature_image
    FileUtils.rm_f(DUMMY_VIDEO_FEATURE_IMAGE_PATH) if File.exist?(DUMMY_VIDEO_FEATURE_IMAGE_PATH)
  end
  Minitest.after_run { cleanup_dummy_video_feature_image }
end
