# Lexxy 0.9.3.beta / Rails 8.1 compatibility shim.
#
# Lexxy's engine registers an on_load(:action_text_content) hook that does:
#
#   default_allowed_tags = Class.new.include(ActionText::ContentHelper).new.sanitizer_allowed_tags
#   ActionText::ContentHelper.allowed_tags = default_allowed_tags + %w[ video audio … ]
#
# On Rails 8.1 `sanitizer_allowed_tags` returns `true` (a "configured?" probe)
# instead of the array, so `+ %w[…]` raises NoMethodError. The exception
# propagates out of the load hook and swallows every subsequent
# on_load(:action_text_content) callback in the boot chain — including the
# Action Text figure/iframe/attachment additions the app needs.
#
# Workaround: set allowed_tags + allowed_attributes explicitly here, using
# the HTML5 sanitizer defaults as the base. Remove this file once Lexxy
# ships a Rails 8.1-compatible release.

Rails.application.config.after_initialize do
  base_tags  = Rails::HTML5::SafeListSanitizer.allowed_tags.to_a
  base_attrs = Rails::HTML5::SafeListSanitizer.allowed_attributes.to_a

  lexxy_tags        = %w[ video audio source embed table tbody tr th td ]
  action_text_tags  = %w[ figure iframe action-text-attachment ]
  action_text_attrs = %w[
    src title frameborder allowfullscreen loading allow style
    sgid content content-type caption presentation
  ]

  ActionText::ContentHelper.allowed_tags       = (base_tags  + lexxy_tags + action_text_tags).uniq
  ActionText::ContentHelper.allowed_attributes = (base_attrs + action_text_attrs).uniq
end
