class CreateAuthors < ActiveRecord::Migration[8.0]
  def change
    create_table :authors do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.text :bio
      t.string :website
      t.string :slug
      t.string :twitter_handle
      t.string :linkedin_url
      t.string :github_username
      t.integer :status
      t.integer :role
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
