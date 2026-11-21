require "test_helper"

class Admin::ArticleFormTest < ActionDispatch::IntegrationTest
  test "the article form asks for a title and a body before it is sent" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    get edit_admin_article_path(articles(:article_published_tech))
    assert_select "input[name=?][required][minlength=5][maxlength=200]", "article[title]"
    assert_select "lexxy-editor[name=?][required]", "article[content]"
  end
end
