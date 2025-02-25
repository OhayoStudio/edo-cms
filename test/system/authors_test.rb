require "application_system_test_case"

class AuthorsTest < ApplicationSystemTestCase
  setup do
    @author = authors(:one)
  end

  test "visiting the index" do
    visit authors_url
    assert_selector "h1", text: "Authors"
  end

  test "should create author" do
    visit authors_url
    click_on "New author"

    fill_in "Bio", with: @author.bio
    fill_in "Deleted at", with: @author.deleted_at
    fill_in "Email", with: @author.email
    fill_in "First name", with: @author.first_name
    fill_in "Github username", with: @author.github_username
    fill_in "Last name", with: @author.last_name
    fill_in "Linkedin url", with: @author.linkedin_url
    fill_in "Role", with: @author.role
    fill_in "Slug", with: @author.slug
    fill_in "Status", with: @author.status
    fill_in "Twitter handle", with: @author.twitter_handle
    fill_in "Website", with: @author.website
    click_on "Create Author"

    assert_text "Author was successfully created"
    click_on "Back"
  end

  test "should update Author" do
    visit author_url(@author)
    click_on "Edit this author", match: :first

    fill_in "Bio", with: @author.bio
    fill_in "Deleted at", with: @author.deleted_at.to_s
    fill_in "Email", with: @author.email
    fill_in "First name", with: @author.first_name
    fill_in "Github username", with: @author.github_username
    fill_in "Last name", with: @author.last_name
    fill_in "Linkedin url", with: @author.linkedin_url
    fill_in "Role", with: @author.role
    fill_in "Slug", with: @author.slug
    fill_in "Status", with: @author.status
    fill_in "Twitter handle", with: @author.twitter_handle
    fill_in "Website", with: @author.website
    click_on "Update Author"

    assert_text "Author was successfully updated"
    click_on "Back"
  end

  test "should destroy Author" do
    visit author_url(@author)
    click_on "Destroy this author", match: :first

    assert_text "Author was successfully destroyed"
  end
end
