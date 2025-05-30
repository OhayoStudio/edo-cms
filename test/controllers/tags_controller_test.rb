require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  fixtures :tags, :articles, :authors, :categories 

  setup do
    @tag = tags(:tag_ruby) # Using descriptive fixture name
    # Ensure fixture data is unique if necessary for specific test logic.
    # Example: @tag.update!(name: "Tag Ruby Test #{Time.now.to_f}", slug: "tag-ruby-test-#{Time.now.to_f}")

    @other_tag = tags(:tag_rails) # Using another descriptive fixture name
    
    # Setup for the 'show' action which renders articles/index
    @author_for_tag_article = authors(:author_jane) # Descriptive name
    @category_for_tag_article = categories(:category_technology) # Descriptive name
    
    @published_article_for_tag = articles(:article_published_tech) # Descriptive name
    # Ensure this article is suitable (e.g., correct author/category if not set by fixture)
    @published_article_for_tag.update!(
      author: @author_for_tag_article, 
      category: @category_for_tag_article
    ) unless @published_article_for_tag.author == @author_for_tag_article && @published_article_for_tag.category == @category_for_tag_article
    
    # Ensure the tag is associated with this article
    @tag.articles << @published_article_for_tag unless @tag.articles.include?(@published_article_for_tag)

    # Create a draft article associated with @tag to ensure it's not shown on tag page
    @draft_article_for_tag = Article.create!(
      title: "Draft Article for Tag Controller Show Test #{Time.now.to_f}",
      author: @author_for_tag_article,
      category: @category_for_tag_article,
      content: "Draft content for tag controller.",
      reading_time: 5,
      status: :draft
    )
    @tag.articles << @draft_article_for_tag unless @tag.articles.include?(@draft_article_for_tag)
  end

  test "should get index and assign tags" do
    get tags_url
    assert_response :success
    assert_not_nil assigns(:tags), "@tags instance variable should be assigned"
  end

  test "should get new and assign a new tag" do
    get new_tag_url
    assert_response :success
    assert_instance_of Tag, assigns(:tag), "A new Tag instance should be assigned"
    assert assigns(:tag).new_record?, "Assigned @tag should be a new record"
  end

  test "should create tag with valid parameters" do
    unique_tag_name = "New Test Tag Create Ctrl #{Time.now.to_f}"
    tag_params = {
      name: unique_tag_name,
      description: "Description for the new test tag created in controller test."
    }

    assert_difference("Tag.count", 1, "Tag count should increment by 1") do
      post tags_url, params: { tag: tag_params }
    end

    created_tag = Tag.last
    assert_redirected_to tag_url(created_tag), "Should redirect to the created tag's show page"
    assert_equal "Tag was successfully created.", flash[:notice], "Flash notice for creation should be set"
    assert_equal unique_tag_name, created_tag.name
    assert_equal unique_tag_name.parameterize, created_tag.slug, "Slug should be auto-generated from name"
  end

  test "should show tag, assign instance variables, and render articles/index template" do
    get tag_url(@tag) # @tag is tags(:tag_ruby)
    assert_response :success
    
    assert_equal @tag, assigns(:tag), "@tag instance variable should be assigned correctly"
    assert_not_nil assigns(:articles), "@articles for the tag should be assigned"
    assert_not_nil assigns(:tags), "All @tags for sidebar/etc. should be assigned"
    assert_not_nil assigns(:categories), "All @categories for sidebar/etc. should be assigned"
    assert_template "articles/index", "Should render the 'articles/index' template for tag show page"
    
    assigned_articles = assigns(:articles)
    assert_includes assigned_articles, @published_article_for_tag
    assert_not_includes assigned_articles, @draft_article_for_tag, "Draft articles should not be shown on tag page"
    assigned_articles.each do |article|
      assert article.published?, "Only published articles should be listed for a tag"
      assert_includes article.tags, @tag, "Articles shown should belong to the current tag"
    end
  end
  
  test "should show tag using its slug directly in URL parameter" do
    get tag_url(id: @tag.slug) # @tag is tags(:tag_ruby)
    assert_response :success
    assert_equal @tag, assigns(:tag), "Should find tag by slug and assign it"
  end

  test "should get edit for a tag and assign it" do
    get edit_tag_url(@tag)
    assert_response :success
    assert_equal @tag, assigns(:tag), "@tag instance variable should be assigned for edit"
  end

  test "should update tag with valid parameters" do
    updated_tag_name = "Updated Tag Name Controller Test #{Time.now.to_f}"
    patch tag_url(@tag), params: { 
      tag: { 
        name: updated_tag_name, 
        description: "Updated tag description in controller test."
      } 
    }
    assert_redirected_to tag_url(@tag), "Should redirect to the tag's show page after update"
    @tag.reload
    
    assert_equal updated_tag_name, @tag.name, "Tag name should be updated"
    assert_equal "Updated tag description in controller test.", @tag.description, "Tag description should be updated"
    assert_equal "Tag was successfully updated.", flash[:notice], "Flash notice for update should be set"
  end

  test "should destroy tag" do
    tag_to_delete = Tag.create!(name: "Delete Me Tag Controller Test #{Time.now.to_f}")
    # Associate an article to test join table record deletion
    tag_to_delete.articles << @published_article_for_tag 

    assert_difference("Tag.count", -1, "Tag count should decrease by 1") do
      # Check that join table records are removed.
      # The number of records removed should be equal to the number of articles associated with tag_to_delete.
      assert_difference("ArticlesTag.count", -tag_to_delete.articles.count) do
         delete tag_url(tag_to_delete)
      end
    end

    assert_redirected_to tags_url, "Should redirect to tags index page after destruction"
    assert_equal "Tag was successfully destroyed.", flash[:notice], "Flash notice for destruction should be set"
    
    assert Article.exists?(@published_article_for_tag.id), "Article associated with deleted tag should still exist"
  end

  test "should not create tag with invalid parameters (e.g., blank name)" do
    assert_no_difference("Tag.count", "Tag count should not change with invalid params") do
      post tags_url, params: { tag: { name: "", description: "Attempt to create with blank name in controller test" } }
    end
    assert_response :unprocessable_entity, "Response should be :unprocessable_entity for invalid create params"
    assert_template :new, "Should re-render the 'new' template"
  end

  test "should not update tag with invalid parameters (e.g., blank name)" do
    original_name = @tag.name
    patch tag_url(@tag), params: { tag: { name: "" } } # Invalid: name is blank
    assert_response :unprocessable_entity, "Response should be :unprocessable_entity for invalid update params"
    assert_template :edit, "Should re-render the 'edit' template"
    @tag.reload
    assert_equal original_name, @tag.name, "Tag name should not change with invalid update params"
  end
end
