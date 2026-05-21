require "kramdown"

# Renders static markdown pages from db/seeds/pages/<slug>.<locale>.md.
#
# Adding a new page:
#   1. Drop <slug>.<locale>.md files into db/seeds/pages/
#      (only one locale is required — others fall back via
#      I18n.default_locale)
#   2. Append the slug to SLUGS below
#   3. Add a named route in config/routes.rb inside the (:locale) scope:
#        get "<slug>" => "pages#show", defaults: { slug: "<slug>" }, as: :<slug>
#   4. Optional: add `pages.<slug>.title` to config/locales/views/pages.<locale>.yml
#      for an <h1> and <title> tag
class PagesController < ApplicationController
  # Whitelist — anything that hits #show with a slug not in this list
  # gets a 404 instead of a path-traversal opportunity.
  SLUGS = %w[terms privacy].freeze

  def show
    slug = params[:slug].to_s
    return head :not_found unless SLUGS.include?(slug)

    path = page_path(slug, I18n.locale) || page_path(slug, I18n.default_locale)
    return head :not_found unless path

    @slug  = slug
    @title = t("pages.#{slug}.title", default: slug.titleize)
    @html  = render_markdown(path)
  end

  private

  # Return the Pathname if a translation exists for this locale, else
  # nil. Lets us fall back to the default locale for pages that only
  # have a single-language source.
  def page_path(slug, locale)
    candidate = Rails.root.join("db/seeds/pages/#{slug}.#{locale}.md")
    candidate if candidate.exist?
  end

  def render_markdown(path)
    Kramdown::Document.new(path.read, auto_ids: true, hard_wrap: false).to_html.html_safe
  end
end
