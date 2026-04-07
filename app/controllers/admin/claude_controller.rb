class Admin::ClaudeController < Admin::BaseController
  include ActionController::Live

  def draft
    response.headers["Content-Type"]      = "text/event-stream"
    response.headers["Cache-Control"]     = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    prompt = params[:prompt].to_s.strip
    return head :bad_request if prompt.blank?

    usage = ClaudeWritingService.new.stream(prompt) do |chunk|
      response.stream.write("data: #{chunk.gsub("\n", "\\n")}\n\n")
    end
    usage_json = {
      input_tokens:                usage.input_tokens,
      output_tokens:               usage.output_tokens,
      cache_creation_input_tokens: usage.cache_creation_input_tokens || 0,
      cache_read_input_tokens:     usage.cache_read_input_tokens     || 0
    }.to_json
    response.stream.write("event: done\ndata: #{usage_json}\n\n")
  rescue ActionController::Live::ClientDisconnected
    # client navigated away — normal
  rescue => e
    Rails.logger.error "[ClaudeController] #{e.class}: #{e.message}"
    msg = e.message.gsub("\n", " ")
    response.stream.write("event: error\ndata: #{msg}\n\n")
  ensure
    response.stream.close
  end
end
