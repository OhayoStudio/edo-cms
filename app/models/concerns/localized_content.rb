# Bilingual rich-text fields for models like About and Colophon.
#
#   class About < ApplicationRecord
#     include LocalizedContent
#     has_localized_content :content
#   end
#
# Declares `has_rich_text :content_<locale>` for every entry in
# `I18n.available_locales`, plus a `#content` method that returns the
# rich text for the current locale, falling back through
# I18n.fallbacks when the active locale is empty.
#
# Adding a new locale = bump config.i18n.available_locales in
# application.rb. The concern picks it up automatically; no model
# change required. Existing rows just need their action_text_rich_texts
# entry to gain a sibling with the new `name` for that locale.
module LocalizedContent
  extend ActiveSupport::Concern

  class_methods do
    def has_localized_content(name = :content)
      I18n.available_locales.each do |loc|
        has_rich_text :"#{name}_#{loc}"
      end

      define_method(name) do
        primary = public_send("#{name}_#{I18n.locale}")
        return primary if primary.body.present?

        I18n.fallbacks[I18n.locale].drop(1).each do |fb|
          rt = public_send("#{name}_#{fb}")
          return rt if rt.body.present?
        end

        primary
      end
    end
  end
end
