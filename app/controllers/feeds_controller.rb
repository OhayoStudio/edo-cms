class FeedsController < ApplicationController
  def index
    @stories = Story.published.recent.with_slug
                    .includes(:storyable)
                    .limit(50)

    respond_to do |format|
      format.rss { render layout: false, content_type: "text/xml" }
    end
  end
end
