# app/components/videos_component.rb
class VideosComponent < ViewComponent::Base
    attr_reader :videos

    def initialize(videos:)
        @videos = videos
        @main_video = videos.first
        @videos = (@videos - [@main_video]).first(3) if @videos.length > 4
    end
end
