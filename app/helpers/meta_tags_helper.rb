module MetaTagsHelper
  SITE_NAME        = "Edo CMS"
  SITE_URL         = "https://example.com"
  DEFAULT_DESC     = "Independent publishing by Edo CMS. Essays, stories, and videos about culture, technology, and the human experience."
  DEFAULT_OG_IMAGE = "/og-default.jpg"  # served from public/

  # Meta description fallback chain:
  # meta_description → excerpt → subtitle → description → site default
  def meta_description_for(record)
    return DEFAULT_DESC unless record
    record.try(:meta_description).presence ||
      record.try(:excerpt).presence        ||
      record.try(:subtitle).presence       ||
      record.try(:description).presence    ||
      DEFAULT_DESC
  end

  # OG image: featured_image → avatar → public fallback
  def og_image_url_for(record)
    if record.try(:featured_image)&.attached?
      rails_representation_url(
        record.featured_image.variant(:og),
        host: SITE_URL
      )
    elsif record.try(:avatar)&.attached?
      rails_representation_url(record.avatar.variant(:thumb), host: SITE_URL)
    else
      "#{SITE_URL}#{DEFAULT_OG_IMAGE}"
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
      "@id"   => "#{SITE_URL}/#organization",
      "name"  => SITE_NAME,
      "url"   => SITE_URL,
      "logo"  => { "@type" => "ImageObject", "url" => "#{SITE_URL}/icon.png" }
    }
  end

  # Reusable schema.org Person fragment for an article author
  def schema_author_for(author)
    return schema_publisher unless author
    h = {
      "@type" => "Person",
      "@id"   => "#{SITE_URL}#{author_path(author)}",
      "name"  => author.full_name,
      "url"   => "#{SITE_URL}#{author_path(author)}"
    }
    h["image"]  = rails_representation_url(author.avatar.variant(:thumb), host: SITE_URL) if author.avatar.attached?
    h["sameAs"] = [ "https://twitter.com/#{author.twitter_handle}" ] if author.twitter_handle.present?
    h
  end
end
