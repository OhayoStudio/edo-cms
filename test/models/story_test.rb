require "test_helper"

class StoryTest < ActiveSupport::TestCase
  fixtures :stories, :articles, :videos, :authors, :categories

  setup do
    # Use descriptive fixture names for storyables
    @article_published = articles(:article_published_tech)
    @article_draft = articles(:article_draft_lifestyle)
    @article_review = articles(:article_review_general) # Used for scheduled story
    @article_archived = articles(:article_archived_tech)

    @video_rails_intro = videos(:video_intro_rails)
    @video_api_design = videos(:video_api_design)

    # Setup specific story instances for general tests and scope tests, referencing descriptive storyables
    @story_article_published_tech = stories(:story_for_article_published_tech)
    @story_video_intro_rails = stories(:story_for_video_intro_rails)

    @story_article_draft_lifestyle = stories(:story_for_article_draft_lifestyle)
    @story_scheduled = stories(:story_scheduled_article)
    @story_archived_top = stories(:story_for_archived_article_as_top)

    # For tests needing a generic 'top' story, use one that is published and top
    @top_story = @story_for_article_published_tech # This one is is_top: true in stories.yml
    # Or ensure one is explicitly top:
    # @top_story = stories(:story_for_video_intro_rails) # This is also top in current stories.yml
    # If a different one is needed, create it or use another descriptive fixture.
  end

  test "should belong to a storyable (polymorphic association)" do
    assert_respond_to @story_article_published_tech, :storyable, "Story should respond to :storyable"
    assert_instance_of Article, @story_article_published_tech.storyable, "Storyable for article story should be an Article instance"

    assert_respond_to @story_video_intro_rails, :storyable, "Story should respond to :storyable"
    assert_instance_of Video, @story_video_intro_rails.storyable, "Storyable for video story should be a Video instance"
  end

  test "should be savable with valid storyable and attributes" do
    # Use a specific article fixture for creating a new story
    article_for_new_story = articles(:article_review_general)
    story = Story.new(
      storyable: article_for_new_story,
      slug: "savable-story-test-slug-#{Time.now.to_i}", # Ensure unique slug for test
      is_published: true,
      published_at: Time.current
    )
    assert story.save, "Story should save with valid attributes. Errors: #{story.errors.full_messages.join(", ")}"
  end

  # Scopes
  test "published scope should return only published stories" do
    published_stories_scope = Story.published
    assert_includes published_stories_scope, @story_article_published_tech
    assert_includes published_stories_scope, @story_video_intro_rails
    assert_includes published_stories_scope, @story_archived_top # This story is published, even if article is archived
    assert_not_includes published_stories_scope, @story_article_draft_lifestyle # This is is_published: false
    assert_not_includes published_stories_scope, @story_scheduled # This is is_published: false
  end

  test "recent scope should order stories by published_at descending" do
    # Fixtures already provide a range of published_at dates.
    # story_for_article_published_tech: '2023-01-15 10:00:00'
    # story_for_video_intro_rails: '2023-02-10 12:00:00'
    # story_for_video_api_design: '2023-02-20 14:30:00'
    # story_for_archived_article_as_top: '2022-10-01 09:00:00'

    # Get published stories ordered by recent scope
    recent_stories_from_scope = Story.published.recent.to_a

    # Manually create the expected order from published fixtures
    expected_ordered_stories = [
      stories(:story_for_video_api_design),    # '2023-02-20 14:30:00'
      stories(:story_for_video_intro_rails), # '2023-02-10 12:00:00'
      stories(:story_for_article_published_tech), # '2023-01-15 10:00:00'
      stories(:story_for_archived_article_as_top) # '2022-10-01 09:00:00'
    ]

    assert_equal expected_ordered_stories.map(&:id), recent_stories_from_scope.map(&:id), "Recent scope did not order stories correctly by published_at"
  end

  test "with_slug scope should return stories that have a non-nil slug" do
    # All fixtures in stories.yml are defined with slugs.
    story_with_slug = stories(:story_for_article_published_tech)

    # Create a story without a slug for testing (if possible and makes sense for the model)
    # Story model doesn't validate presence of slug.
    storyable_for_no_slug_test = articles(:article_draft_lifestyle)
    story_without_slug = Story.create!(storyable: storyable_for_no_slug_test, slug: nil, is_published: false)

    stories_with_slugs_scope = Story.with_slug
    assert_includes stories_with_slugs_scope, story_with_slug
    assert_not_includes stories_with_slugs_scope, story_without_slug, "Scope should exclude story with a nil slug"
  end

  test "limit_3 scope should return at most 3 stories" do
    # Ensure there are more than 3 stories by adding some if fixtures are insufficient
    # For now, assume fixtures + setup provide enough published stories for this.
    # If not, create more:
    # (1..5).each { |i| Story.create!(storyable: @article_published, slug: "limit-3-filler-#{i}", is_published: true, published_at: Time.current - i.minutes) }
    assert_operator Story.published.count, :>=, 3, "Need at least 3 published stories to test limit_3 scope"
    assert_equal 3, Story.limit_3.count, "limit_3 scope should return 3 stories"
  end

  test "limit_4 scope should return at most 4 stories" do
    assert_operator Story.published.count, :>=, 4, "Need at least 4 published stories to test limit_4 scope"
    assert_equal 4, Story.limit_4.count, "limit_4 scope should return 4 stories"
  end

  test "top scope should return only stories where is_top is true" do
    # From stories.yml:
    # story_for_article_published_tech is is_top: true
    # story_for_video_intro_rails is is_top: true
    # story_for_video_api_design is is_top: false
    # story_for_archived_article_as_top is is_top: true

    top_stories_scope = Story.top
    assert_includes top_stories_scope, stories(:story_for_article_published_tech)
    assert_includes top_stories_scope, stories(:story_for_video_intro_rails)
    assert_includes top_stories_scope, stories(:story_for_archived_article_as_top)
    assert_not_includes top_stories_scope, stories(:story_for_video_api_design)
  end

  # Methods
  test "to_param should return the slug of the story" do
    story_with_known_slug = stories(:story_for_article_published_tech) # slug: "story-for-article-published-tech"
    assert_equal "story-for-article-published-tech", story_with_known_slug.to_param, "to_param did not return the correct slug"
  end
end
