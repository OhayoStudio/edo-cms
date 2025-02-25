class AddReferencesToArticles < ActiveRecord::Migration[8.0]
  def change
    add_reference :articles, :author, null: false, foreign_key: true
    add_reference :articles, :category, null: false, foreign_key: true
  end
end
