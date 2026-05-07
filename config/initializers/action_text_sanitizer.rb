# Allow YouTube iframe embeds AND ActionText attachments in Lexxy/ActionText rich text content.
ActiveSupport.on_load(:action_text_content) do
  # Append to ActionText's own defaults instead of replacing — its defaults
  # already include "action-text-attachment" and the attributes ActionText needs.
  ActionText::ContentHelper.allowed_tags |= %w[ figure iframe action-text-attachment ]
  ActionText::ContentHelper.allowed_attributes |= %w[
    src title frameborder allowfullscreen loading allow style
    sgid content content-type caption presentation
  ]
end
