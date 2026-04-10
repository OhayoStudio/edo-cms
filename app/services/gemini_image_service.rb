require "net/http"
require "base64"

class GeminiImageService
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent"

  def enhance(image_io:, content_type:, prompt:)
    key = ENV.fetch("GEMINI_API_KEY")
    b64 = Base64.strict_encode64(image_io.read)

    body = {
      contents: [ {
        parts: [
          { text: prompt },
          { inline_data: { mime_type: content_type, data: b64 } }
        ]
      } ],
      generationConfig: { responseModalities: [ "image", "text" ] }
    }

    uri      = URI("#{API_URL}?key=#{key}")
    req      = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    req.body = body.to_json

    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120) do |http|
      http.request(req)
    end

    unless res.is_a?(Net::HTTPSuccess)
      raise "Gemini API error #{res.code}: #{res.body.truncate(300)}"
    end

    data = JSON.parse(res.body)
    part = data.dig("candidates", 0, "content", "parts")&.find { |p| p["inlineData"] }
    raise "Gemini returned no image" unless part

    {
      data:         Base64.decode64(part["inlineData"]["data"]),
      content_type: part["inlineData"]["mimeType"]
    }
  end
end
