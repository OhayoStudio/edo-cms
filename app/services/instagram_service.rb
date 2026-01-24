# app/services/instagram_service.rb
class InstagramService
    include HTTParty

    def initialize
      @access_token = ""
      #   @access_token = ENV['INSTAGRAM_ACCESS_TOKEN']
      @base_url = "https://graph.instagram.com/me"
    end

    def get_liked_posts
      response = HTTParty.get("#{@base_url}/media?fields=id,caption,media_type,media_url,permalink,thumbnail_url,timestamp,username&access_token=#{@access_token}")

      if response.success?
        JSON.parse(response.body)["data"]
      else
        raise "Error fetching liked posts: #{response.body}"
      end
    end
end
