class CreateStories < ActiveRecord::Migration[8.0]
  def change
    create_table :stories do |t|
      t.string :slug
      t.boolean :is_published
      t.datetime :published_at
      t.references :storyable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
