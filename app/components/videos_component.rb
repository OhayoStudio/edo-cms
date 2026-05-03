# app/components/videos_component.rb
class VideosComponent < ViewComponent::Base
    attr_reader :videos

    def initialize(videos:)
        all = videos.to_a
        @main_video = all.first
        @videos = (all - [ @main_video ]).first(3)
    end
end
