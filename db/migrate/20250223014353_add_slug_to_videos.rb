class AddSlugToVideos < ActiveRecord::Migration[8.0]
  def up
    add_column :videos, :slug, :string
    add_index :videos, :slug, unique: true
  end

  def down
    remove_column :videos, :slug
  end
end
