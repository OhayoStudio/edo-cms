require "application_system_test_case"

class StoriesTest < ApplicationSystemTestCase
  setup do
    @story = stories(:one)
  end

  test "visiting the index" do
    visit stories_url
    assert_selector "h1", text: "Stories"
  end

  test "should create story" do
    visit stories_url
    click_on "New story"

    check "Is published" if @story.is_published
    fill_in "Published at", with: @story.published_at
    fill_in "Slug", with: @story.slug
    fill_in "Storyable", with: @story.storyable_id
    fill_in "Storyable type", with: @story.storyable_type
    click_on "Create Story"

    assert_text "Story was successfully created"
    click_on "Back"
  end

  test "should update Story" do
    visit story_url(@story)
    click_on "Edit this story", match: :first

    check "Is published" if @story.is_published
    fill_in "Published at", with: @story.published_at.to_s
    fill_in "Slug", with: @story.slug
    fill_in "Storyable", with: @story.storyable_id
    fill_in "Storyable type", with: @story.storyable_type
    click_on "Update Story"

    assert_text "Story was successfully updated"
    click_on "Back"
  end

  test "should destroy Story" do
    visit story_url(@story)
    click_on "Destroy this story", match: :first

    assert_text "Story was successfully destroyed"
  end
end
