xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title       "Edo CMS"
    xml.description "Things worth paying attention to."
    xml.link        root_url
    xml.language    "en"
    xml.tag!("atom:link", href: feed_url(format: :rss), rel: "self", type: "application/rss+xml")

    @stories.each do |story|
      storyable = story.storyable
      next unless storyable

      url = storyable.is_a?(Article) ? article_url(storyable) : video_url(storyable)

      xml.item do
        xml.title       storyable.title
        xml.link        url
        xml.guid        url, isPermaLink: "true"
        xml.pubDate     story.published_at.rfc2822 if story.published_at.present?
        xml.description storyable.try(:excerpt) || storyable.try(:description)
      end
    end
  end
end
