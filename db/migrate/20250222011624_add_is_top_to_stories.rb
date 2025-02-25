class AddIsTopToStories < ActiveRecord::Migration[8.0]
  def change
    add_column :stories, :is_top, :boolean
  end
end
