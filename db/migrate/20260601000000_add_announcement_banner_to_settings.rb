class AddAnnouncementBannerToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :banner_enabled, :boolean, default: false, null: false
    add_column :settings, :banner_cta_url, :string
  end
end
