json.extract! article, :id, :title, :subtitle, :content, :excerpt, :meta_description, :meta_keywords, :featured, :featured_image, :author_id, :category_id, :reading_time, :view_count, :status, :slug, :published_at, :created_at, :updated_at
json.url article_url(article, format: :json)
json.content article.content.to_s
json.featured_image url_for(article.featured_image)
