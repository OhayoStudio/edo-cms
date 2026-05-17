json.extract! article, :id, :title, :subtitle, :excerpt, :meta_description, :meta_keywords, :featured, :author_id, :category_id, :reading_time, :view_count, :status, :slug, :published_at, :created_at, :updated_at
json.url article_url(article, format: :json)
json.content article.content.to_s
json.featured_image article.featured_image.attached? ? url_for(article.featured_image) : nil
