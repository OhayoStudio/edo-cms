class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title
      t.string :subtitle
      t.text :excerpt
      t.string :meta_description
      t.string :meta_keywords
      t.boolean :featured
      t.integer :reading_time
      t.integer :view_count
      t.integer :status
      t.string :slug
      t.datetime :published_at

      t.timestamps
    end
  end
end
