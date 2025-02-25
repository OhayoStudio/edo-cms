class AddArticlesAsStories < ActiveRecord::Migration[6.1]
  def up
    Article.find_each do |article|
      Story.create!(
        storyable: article,
        slug: article.title.parameterize,
        is_published: article.published?,
        published_at: article.published_at
      )
    end
  end

  def down
    Story.where(storyable_type: 'Article').delete_all
  end
end
