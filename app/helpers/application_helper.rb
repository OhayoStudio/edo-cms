module ApplicationHelper
  # True when the attachment has a stored file with a URL. After a failed save the
  # form re-renders with the just-uploaded file attached but not stored yet, and
  # asking that one for a URL raises "Cannot get a signed_id for a new record".
  def stored_attachment?(attachment)
    attachment.attached? && attachment.blob.persisted?
  end

  def articles_section?
    controller_name == "articles"
  end
end
