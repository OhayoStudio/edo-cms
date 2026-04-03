class DropGoogleOauthTokens < ActiveRecord::Migration[8.0]
  def change
    drop_table :google_oauth_tokens
  end
end
