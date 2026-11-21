require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  # Answer as production does: the error page, not the developer's debug page.
  setup do
    @detailed = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
  end

  teardown do
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @detailed
  end

  test "a mistyped article address shows the not found page, not the home page" do
    get "/en/articles/no-such-article"
    assert_response :not_found
    assert_select "h1", "This page doesn't exist"
    assert_select "a[href=?]", "/en"
    assert_select "meta[name=robots][content=noindex]"
  end

  test "an unknown address under /ja is answered in Japanese" do
    get "/ja/no-such-page"
    assert_response :not_found
    assert_select "h1", "このページは見つかりません"
  end

  test "a missing JSON resource gets a bare 404" do
    get "/en/articles/no-such-article", as: :json
    assert_response :not_found
    assert_empty response.body
  end
end
