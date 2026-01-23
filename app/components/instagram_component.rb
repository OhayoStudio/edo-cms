class InstagramComponent < ViewComponent::Base
    # attr_reader :videos

    # def initialize(videos:)
    #     @videos = videos
    #     @main_video = videos.first
    #     @videos = (@videos - [@main_video]).first(3)
    # end

    def initialize
      instagram_service = InstagramService.new
      @liked_posts = instagram_service.get_liked_posts
    end
end
