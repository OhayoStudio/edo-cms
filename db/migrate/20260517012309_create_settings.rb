class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string  :site_name,              default: "My CMS", null: false
      t.string  :tagline
      t.text    :meta_description
      t.string  :contact_email
      t.jsonb   :nav_items,              default: {}, null: false
      t.jsonb   :social_links,           default: {}, null: false
      t.jsonb   :theme_colors,           default: {}, null: false
      t.string  :analytics_provider
      t.string  :analytics_website_id
      t.string  :analytics_host
      t.string  :newsletter_provider
      t.string  :newsletter_form_action
      t.timestamps
    end
  end
end
