# script/flickr_auth.rb
# One-time Flickr OAuth setup. Run with:
#   bin/rails runner script/flickr_auth.rb
#
# Then paste the 3 output lines into .env and restart the server.

require "flickraw"

FlickRaw.api_key       = ENV.fetch("FLICKR_API_KEY")
FlickRaw.shared_secret = ENV.fetch("FLICKR_API_SECRET")
flickr = FlickRaw::Flickr.new

token = flickr.get_request_token
puts "Open this URL in your browser and authorize the app:"
puts flickr.get_authorize_url(token["oauth_token"], perms: "read")
puts
print "Paste the verifier code Flickr gives you: "
verifier = $stdin.gets.chomp

flickr.get_access_token(token["oauth_token"], token["oauth_token_secret"], verifier)
info = flickr.test.login

puts
puts "Add these lines to your .env file:"
puts "FLICKR_ACCESS_TOKEN=#{flickr.access_token}"
puts "FLICKR_ACCESS_TOKEN_SECRET=#{flickr.access_secret}"
puts "FLICKR_USER_NSID=#{info.id}"
puts
puts "Then restart bin/dev."
