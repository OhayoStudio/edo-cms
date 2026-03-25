# Allow YouTube iframe embeds in Lexxy/ActionText rich text content.
ActiveSupport.on_load(:action_text_content) do
  base_tags  = Rails::Html::SafeListSanitizer.allowed_tags.to_a
  base_attrs = Rails::Html::SafeListSanitizer.allowed_attributes.to_a

  ActionText::ContentHelper.allowed_tags  = base_tags  | %w[figure iframe]
  ActionText::ContentHelper.allowed_attributes = base_attrs | %w[
    src title frameborder allowfullscreen loading allow style
  ]
end
