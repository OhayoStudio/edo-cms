class Admin::ClaudeController < Admin::BaseController
  include ActionController::Live

  def draft
    response.headers["Content-Type"]      = "text/event-stream"
    response.headers["Cache-Control"]     = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    prompt = params[:prompt].to_s.strip
    return head :bad_request if prompt.blank?

    ClaudeWritingService.new.stream(prompt) do |chunk|
      response.stream.write("data: #{chunk.gsub("\n", "\\n")}\n\n")
    end
  rescue ActionController::Live::ClientDisconnected
    # client navigated away — normal
  ensure
    response.stream.close
  end
end
