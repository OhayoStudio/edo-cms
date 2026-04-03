class CreateGoogleOauthTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :google_oauth_tokens do |t|
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at

      t.timestamps
    end
  end
end
