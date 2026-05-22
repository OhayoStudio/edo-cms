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
    logo_url = cms_logo_or_favicon_url(absolute: true)
    {
      "@type" => "Organization",
      "@id"   => "#{site_url}/#organization",
      "name"  => site_name,
      "url"   => site_url,
      "logo"  => { "@type" => "ImageObject", "url" => logo_url }
    }
  end

  # Logo for structured data + admin/applications layouts. Prefers
  # Setting#logo_light, then Setting#favicon, then the static
  # public/icon.png fallback. `absolute:` controls host prefixing.
  def cms_logo_or_favicon_url(absolute: false)
    if cms_setting.logo_light.attached?
      rails_representation_url(cms_setting.logo_light, host: (absolute ? site_url : nil))
    elsif cms_setting.favicon.attached?
      rails_representation_url(cms_setting.favicon, host: (absolute ? site_url : nil))
    else
      absolute ? "#{site_url}/icon.png" : "/icon.png"
    end
  end

  # Favicon-shaped URL for <link rel="icon"> tags. Prefers Setting#favicon,
  # falls back to the static public/ files. Pass format: :svg to prefer the
  # SVG fallback when no upload is set.
  def cms_favicon_url(format: :png)
    return rails_representation_url(cms_setting.favicon, only_path: true) if cms_setting.favicon.attached?
    format == :svg ? "/icon.svg" : "/icon.png"
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
