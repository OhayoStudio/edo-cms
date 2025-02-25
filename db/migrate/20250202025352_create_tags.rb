class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name
      t.string :slug
      t.text :description
      t.boolean :featured
      t.string :meta_title
      t.text :meta_description
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
