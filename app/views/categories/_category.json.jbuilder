json.extract! category, :id, :name, :description, :slug, :parent_id, :position, :featured, :status, :meta_title, :meta_description, :deleted_at, :created_at, :updated_at
json.url category_url(category, format: :json)
