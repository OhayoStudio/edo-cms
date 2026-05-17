module MetaTagsHelper
  DEFAULT_OG_IMAGE_PATH = "/og-default.jpg"  # served from public/ as fallback

  def site_name
    cms_setting.site_name.presence || "My CMS"
  end

  def site_url
    host = ENV["APPLICATION_HOST"].presence
    scheme = Rails.env.production? ? "https" : (request&.protocol&.delete_suffix("://") || "http")
    if host.present?
      "#{scheme}://#{host}"
    elsif request
      "#{scheme}://#{request.host_with_port}"
    else
      "http://localhost"
    end
  end

  def default_meta_description
    cms_setting.meta_description.presence || site_name
  end

  # Meta description fallback chain:
  # meta_description → excerpt → subtitle → description → site default
  def meta_description_for(record)
    return default_meta_description unless record
    record.try(:meta_description).presence ||
      record.try(:excerpt).presence        ||
      record.try(:subtitle).presence       ||
      record.try(:description).presence    ||
      default_meta_description
  end

  # OG image: featured_image → avatar → setting default → public fallback
  def og_image_url_for(record)
    if record.try(:featured_image)&.attached?
      rails_representation_url(record.featured_image.variant(:og), host: site_url)
    elsif record.try(:avatar)&.attached?
      rails_representation_url(record.avatar.variant(:thumb), host: site_url)
    elsif cms_setting.og_default_image.attached?
      rails_representation_url(cms_setting.og_default_image, host: site_url)
    else
      "#{site_url}#{DEFAULT_OG_IMAGE_PATH}"
    end
  end

  # Renders a <script type="application/ld+json"> tag safely
  def json_ld_tag(schema_hash)
    content_tag(:script, json_escape(schema_hash.to_json).html_safe,
                type: "application/ld+json")
  end

  # Reusable schema.org Organization fragment (site publisher)
  def schema_publisher
    {
      "@type" => "Organization",
      "@id"   => "#{site_url}/#organization",
      "name"  => site_name,
      "url"   => site_url,
      "logo"  => { "@type" => "ImageObject", "url" => "#{site_url}/icon.png" }
    }
  end

  # Reusable schema.org Person fragment for an article author
  def schema_author_for(author)
    return schema_publisher unless author
    h = {
      "@type" => "Person",
      "@id"   => "#{site_url}#{author_path(author)}",
      "name"  => author.full_name,
      "url"   => "#{site_url}#{author_path(author)}"
    }
    h["image"]  = rails_representation_url(author.avatar.variant(:thumb), host: site_url) if author.avatar.attached?
    h["sameAs"] = [ "https://twitter.com/#{author.twitter_handle}" ] if author.twitter_handle.present?
    h
  end
end
