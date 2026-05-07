class CreatePanoramicImages < ActiveRecord::Migration[8.1]
  def change
    create_table :panoramic_images do |t|
      t.timestamps
    end
  end
end
