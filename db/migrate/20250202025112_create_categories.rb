class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name
      t.text :description
      t.string :slug
      t.integer :parent_id
      t.integer :position
      t.boolean :featured
      t.integer :status
      t.string :meta_title
      t.text :meta_description
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
