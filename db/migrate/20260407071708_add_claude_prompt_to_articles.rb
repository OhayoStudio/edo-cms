class AddClaudePromptToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :claude_prompt, :text
  end
end
