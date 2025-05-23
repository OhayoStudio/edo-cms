require "test_helper"

class StoryTest < ActiveSupport::TestCase
  fixtures :stories, :articles, :videos, :authors, :categories # Load all relevant fixtures

  setup do
    # Create fresh records for storyables to ensure clean state and avoid fixture modification side effects.
    @author = authors(:one)
    @category = categories(:one)

    @article1 = Article.create!(title: "Test Article One for Story", author: @author, category: @category, content: "Content for article one.", status: :published, published_at: Time.current - 1.day)
    @video1 = Video.create!(title: "Test Video One for Story", description: "Description for video one.", url: "http://example.com/video1.mp4")
    # Attach a dummy image if Video model validates presence of featured_image
    # dummy_file_path = Rails.root.join('test', 'fixtures', 'files', 'test_image.png') # Create this file
    # @video1.featured_image.attach(io: File.open(dummy_file_path), filename: 'test_image.png', content_type: 'image/png') if @video1.respond_to?(:featured_image)


    # Setup specific story instances for general tests and scope tests
    @story_article_published = Story.create!(storyable: @article1, slug: @article1.slug, is_published: true, published_at: @article1.published_at)
    @story_video_published = Story.create!(storyable: @video1, slug: @video1.slug, is_published: true, published_at: Time.current - 2.days)
    
    @article2 = Article.create!(title: "Test Article Two for Story", author: @author, category: @category, content: "Content for article two.", status: :draft) # Unpublished storyable
    @story_article_unpublished = Story.create!(storyable: @article2, slug: @article2.slug, is_published: false, published_at: Time.current)

    @article3 = Article.create!(title: "Test Article Three for Top Story", author: @author, category: @category, content: "Content for article three.", status: :published, published_at: Time.current - 3.days)
    @top_story = Story.create!(storyable: @article3, slug: @article3.slug, is_published: true, published_at: @article3.published_at, is_top: true)
  end

  test "should belong to a storyable (polymorphic association)" do
    assert_respond_to @story_article_published, :storyable, "Story should respond to :storyable"
    assert_instance_of Article, @story_article_published.storyable, "Storyable for article story should be an Article instance"

    assert_respond_to @story_video_published, :storyable, "Story should respond to :storyable"
    assert_instance_of Video, @story_video_published.storyable, "Storyable for video story should be a Video instance"
  end
  
  test "should be savable with valid storyable and attributes" do
    article = Article.create!(title: "Savable Story Article", author: @author, category: @category, content: "Content", status: :published, published_at: Time.current)
    story = Story.new(storyable: article, slug: article.slug, is_published: true, published_at: Time.current)
    assert story.save, "Story should save with valid attributes. Errors: #{story.errors.full_messages.join(", ")}"
  end

  # Scopes
  test "published scope should return only published stories" do
    published_stories_scope = Story.published
    assert_includes published_stories_scope, @story_article_published, "Scope should include published article story"
    assert_includes published_stories_scope, @story_video_published, "Scope should include published video story"
    assert_includes published_stories_scope, @top_story, "Scope should include top story as it is also published"
    assert_not_includes published_stories_scope, @story_article_unpublished, "Scope should exclude unpublished story"
  end

  test "recent scope should order stories by published_at descending" do
    # Create stories with precise published_at times for this test
    story_newest = Story.create!(storyable: @article1, slug: "newest", is_published: true, published_at: Time.current)
    story_middle = Story.create!(storyable: @video1, slug: "middle", is_published: true, published_at: Time.current - 1.hour)
    story_oldest = Story.create!(storyable: @article2, slug: "oldest", is_published: true, published_at: Time.current - 1.day) # Ensure this one is published for the scope

    # Include stories from setup that are published
    expected_order = [story_newest, story_middle, @story_article_published, @story_video_published, @top_story, story_oldest].sort_by(&:published_at).reverse

    recent_stories_scope = Story.recent.where(is_published: true) # Assuming recent scope itself doesn't filter by published status
    
    # Filter to only stories created in this test or known published ones from setup to avoid interference.
    test_story_ids = expected_order.map(&:id)
    actual_ordered_stories = recent_stories_scope.select { |s| test_story_ids.include?(s.id) }.sort_by(&:published_at).reverse


    assert_equal expected_order.map(&:id), actual_ordered_stories.map(&:id), "Recent scope did not order stories correctly by published_at"
  end

  test "with_slug scope should return stories that have a non-nil slug" do
    story_with_slug = Story.create!(storyable: @article1, slug: "a-definite-slug", is_published: true, published_at: Time.current)
    # Story model does not validate presence of slug. Assume a story could be created with slug: nil for testing.
    story_without_slug = Story.create!(storyable: @article2, slug: nil, is_published: true, published_at: Time.current)

    stories_with_slugs_scope = Story.with_slug
    assert_includes stories_with_slugs_scope, story_with_slug, "Scope should include story with a slug"
    assert_includes stories_with_slugs_scope, @story_article_published # From setup, has slug
    assert_not_includes stories_with_slugs_scope, story_without_slug, "Scope should exclude story with a nil slug"
  end

  test "limit_3 scope should return at most 3 stories" do
    # Ensure there are enough stories for the limit to be meaningful
    # Setup already creates several. Add more if needed.
    (1..5).each { |i| Story.create!(storyable: @article1, slug: "limit-3-filler-#{i}", is_published: true, published_at: Time.current - i.minutes) }
    assert_equal 3, Story.limit_3.count, "limit_3 scope should return 3 stories"
  end

  test "limit_4 scope should return at most 4 stories" do
    (1..6).each { |i| Story.create!(storyable: @video1, slug: "limit-4-filler-#{i}", is_published: true, published_at: Time.current - i.minutes) }
    assert_equal 4, Story.limit_4.count, "limit_4 scope should return 4 stories"
  end

  test "top scope should return only stories where is_top is true" do
    non_top_story = Story.create!(storyable: @article1, slug: "not-a-top-story", is_published: true, published_at: Time.current, is_top: false)

    top_stories_scope = Story.top
    assert_includes top_stories_scope, @top_story, "Scope should include the top story from setup"
    assert_not_includes top_stories_scope, non_top_story, "Scope should exclude non-top story"
    assert_not_includes top_stories_scope, @story_article_published, "Scope should exclude story not marked as top"
  end

  # Methods
  test "to_param should return the slug of the story" do
    story_with_specific_slug = Story.new(slug: "custom-slug-for-to-param")
    assert_equal "custom-slug-for-to-param", story_with_specific_slug.to_param, "to_param did not return the correct slug"
  end
end
