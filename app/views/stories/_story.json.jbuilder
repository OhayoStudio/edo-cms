json.extract! story, :id, :slug, :is_published, :published_at, :storyable_id, :storyable_type, :created_at, :updated_at
json.url story_url(story, format: :json)
