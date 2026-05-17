class DropPanoramicImagesAndStrippedFields < ActiveRecord::Migration[8.1]
  def change
    drop_table :panoramic_images, if_exists: true do |t|
      t.timestamps
    end

    remove_column :articles, :claude_prompt, :text, if_exists: true
  end
end
