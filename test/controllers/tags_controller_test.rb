require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  fixtures :tags, :articles, :authors, :categories 

  setup do
    @tag = tags(:one)
    @tag.update!(
      name: "Tag Controller Test One #{Time.now.to_f}", # Ensure unique name for tests
      slug: "tag-controller-test-one-#{Time.now.to_f}"  # Ensure unique slug
    )

    @other_tag = tags(:two) 
    @other_tag.update!(
      name: "Tag Controller Test Two #{Time.now.to_f}", 
      slug: "tag-controller-test-two-#{Time.now.to_f}"
    )
    
    # Setup for the 'show' action which renders articles/index
    @author_for_tag_article = authors(:one)
    @author_for_tag_article.update!(email: "tag_show_author_#{Time.now.to_f}@example.com") # Ensure valid author

    @category_for_tag_article = categories(:one)
    @category_for_tag_article.update!(name: "Tag Show Category #{Time.now.to_f}", description: "Desc for tag show cat") # Ensure valid category
    
    # Create a published article and associate it with @tag for testing the show page
    @published_article_for_tag = Article.create!(
      title: "Published Article for Tag Show Test #{Time.now.to_f}", 
      author: @author_for_tag_article, 
      category: @category_for_tag_article, 
      content: "Content for tag show test.", 
      status: :published, 
      published_at: Time.current
    )
    @tag.articles << @published_article_for_tag

    # Create a draft article associated with @tag to ensure it's not shown
    @draft_article_for_tag = Article.create!(
      title: "Draft Article for Tag Show Test #{Time.now.to_f}",
      author: @author_for_tag_article,
      category: @category_for_tag_article,
      content: "Draft content.",
      status: :draft
    )
    @tag.articles << @draft_article_for_tag
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
    unique_tag_name = "New Test Tag Create #{Time.now.to_f}"
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
    get tag_url(@tag) # Uses @tag.to_param which should be its slug
    assert_response :success
    
    assert_equal @tag, assigns(:tag), "@tag instance variable should be assigned correctly"
    assert_not_nil assigns(:articles), "@articles for the tag should be assigned"
    assert_not_nil assigns(:tags), "All @tags for sidebar/etc. should be assigned"
    assert_not_nil assigns(:categories), "All @categories for sidebar/etc. should be assigned"
    assert_template "articles/index", "Should render the 'articles/index' template for tag show page"
    
    # Verify that only published articles associated with @tag are shown
    assigned_articles = assigns(:articles)
    assert_includes assigned_articles, @published_article_for_tag
    assert_not_includes assigned_articles, @draft_article_for_tag, "Draft articles should not be shown on tag page"
    assigned_articles.each do |article|
      assert article.published?, "Only published articles should be listed for a tag"
      assert_includes article.tags, @tag, "Articles shown should belong to the current tag"
    end
  end
  
  test "should show tag using its slug directly in URL parameter" do
    get tag_url(id: @tag.slug) # Explicitly use slug in 'id' param
    assert_response :success
    assert_equal @tag, assigns(:tag), "Should find tag by slug and assign it"
  end

  test "should get edit for a tag and assign it" do
    get edit_tag_url(@tag)
    assert_response :success
    assert_equal @tag, assigns(:tag), "@tag instance variable should be assigned for edit"
  end

  test "should update tag with valid parameters" do
    updated_tag_name = "Updated Tag Name Test #{Time.now.to_f}"
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
    # Tag model has has_and_belongs_to_many :articles. Default is no dependent destruction for HABTM.
    # The join table records (articles_tags) will be deleted. Articles themselves won't.
    tag_to_delete = Tag.create!(name: "Delete Me Tag Test #{Time.now.to_f}")
    tag_to_delete.articles << @published_article_for_tag # Associate with an article

    assert_difference("Tag.count", -1, "Tag count should decrease by 1") do
      assert_difference("ArticlesTag.count", -@tag.articles.count) do # Check join table records are removed
         delete tag_url(@tag) # Use @tag from setup, it has associated articles
      end
    end


    assert_redirected_to tags_url, "Should redirect to tags index page after destruction"
    assert_equal "Tag was successfully destroyed.", flash[:notice], "Flash notice for destruction should be set"
    
    # Verify that the article itself was not deleted
    assert Article.exists?(@published_article_for_tag.id), "Article associated with deleted tag should still exist"
  end

  test "should not create tag with invalid parameters (e.g., blank name)" do
    assert_no_difference("Tag.count", "Tag count should not change with invalid params") do
      post tags_url, params: { tag: { name: "", description: "Attempt to create with blank name" } }
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
