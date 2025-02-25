json.extract! author, :id, :first_name, :last_name, :email, :bio, :website, :avatar, :slug, :twitter_handle, :linkedin_url, :github_username, :status, :role, :deleted_at, :created_at, :updated_at
json.url author_url(author, format: :json)
json.avatar url_for(author.avatar)
