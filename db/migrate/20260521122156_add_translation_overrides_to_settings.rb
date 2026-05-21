class AddTranslationOverridesToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :translation_overrides, :jsonb, default: {}, null: false
  end
end
