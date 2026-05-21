# Bilingual rich-text rollout. About + Colophon used to expose a single
# `content` ActionText association. They now expose
# `content_<locale>` (see LocalizedContent concern). Existing data is
# moved into `content_<default_locale>` so the old body is preserved;
# editors fill in the other locales after deploy.
class RenameAboutColophonContentToLocaleScoped < ActiveRecord::Migration[8.1]
  def up
    new_name = "content_#{I18n.default_locale}"
    execute <<~SQL
      UPDATE action_text_rich_texts
      SET name = '#{new_name}'
      WHERE record_type IN ('About', 'Colophon')
        AND name = 'content'
    SQL
  end

  def down
    old_name = "content_#{I18n.default_locale}"
    execute <<~SQL
      UPDATE action_text_rich_texts
      SET name = 'content'
      WHERE record_type IN ('About', 'Colophon')
        AND name = '#{old_name}'
    SQL
  end
end
