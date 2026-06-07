require "test_helper"

class StoriesControllerTest < ActionDispatch::IntegrationTest
  fixtures :stories, :articles, :videos, :authors, :categories

  DUMMY_IMAGE = Rails.root.join("test", "fixtures", "files", "dummy_video_image.png").freeze

  def self.ensure_dummy_image
    return if File.exist?(DUMMY_IMAGE)
    FileUtils.mkdir_p(File.dirname(DUMMY_IMAGE))
    File.binwrite(DUMMY_IMAGE, "dummy image content for stories controller test")
  end
  ensure_dummy_image

  setup do
    # The top story is the most recent published, slugged, is_top story. Among
    # the fixtures that is story_for_video_intro_rails (2023-02-10), which is
    # more recent than story_for_article_published_tech (2023-01-15).
    @top_story = stories(:story_for_video_intro_rails)
    @draft_story = stories(:story_for_article_draft_lifestyle)

    # The homepage renders the videos rail, whose thumbnails require an
    # attached featured_image on each shown video.
    Video.joins(:story).where(stories: { is_published: true }).find_each do |video|
      next if video.featured_image.attached?
      video.featured_image.attach(io: File.open(DUMMY_IMAGE), filename: "dummy_video_image.png", content_type: "image/png")
      video.save!
    end
  end

  test "should get index and assign homepage collections" do
    get stories_url
    assert_response :success

    assert_equal @top_story, assigns(:top_story), "Incorrect top story assigned"

    assert_not_nil assigns(:recent_stories), "@recent_stories should be assigned"
    assert_not_includes assigns(:recent_stories).map(&:id), @top_story.id,
                        "Top story should be excluded from recent stories"
    assert_not_includes assigns(:recent_stories).map(&:id), @draft_story.id,
                        "Unpublished stories should be excluded from recent stories"

    assert_not_nil assigns(:videos), "@videos should be assigned"
    assert_includes assigns(:videos).map(&:id), videos(:video_intro_rails).id,
                    "Videos list should include a known published video"

    assert_not_nil assigns(:latest_stories_by_category), "@latest_stories_by_category should be assigned"
    category_ids = assigns(:latest_stories_by_category).map { |s| s.storyable.category_id }
    assert_equal category_ids.uniq.count, category_ids.count,
                 "There should be only one latest story per category"
  end

  test "should show a story by id and assign it" do
    # Requested as JSON: the controller finds the story by id and assigns it.
    # (The HTML show template is part of the admin-era chrome that is no longer
    # wired for the public route, so JSON exercises the controller cleanly.)
    get story_url(id: @top_story.id, format: :json)
    assert_response :success
    assert_equal @top_story, assigns(:story), "@story should be assigned correctly"
  end
end
