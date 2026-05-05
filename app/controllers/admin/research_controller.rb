class Admin::ResearchController < Admin::BaseController
  include ActionController::Live

  AGENT_ID       = "agent_011Cagbw3na9mVPpXykGsVfK"
  ENVIRONMENT_ID = "env_01ABCupXsF27coyrhk78nNNm"
  API_BASE       = "https://api.anthropic.com"
  BETA_HEADER    = "managed-agents-2026-04-01"

  def stream
    prompt = params[:prompt].to_s.strip
    return head :bad_request if prompt.blank?

    response.headers["Content-Type"]      = "text/event-stream"
    response.headers["Cache-Control"]     = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    sse = response.stream

    begin
      session_id = create_agent_session!
      raise "Could not create research session" unless session_id

      # Send user message after the SSE stream connection is established
      send_thread = Thread.new do
        sleep 0.3
        send_user_message(session_id, prompt)
      end

      # Open the event stream and proxy chunks to the browser
      stream_events(session_id, sse)

      send_thread.join
    rescue IOError
      # client disconnected — normal
    rescue => e
      sse.write("event: error\ndata: #{e.message.to_json}\n\n")
    ensure
      sse.close
    end
  end

  private

  def create_agent_session!
    res = HTTParty.post(
      "#{API_BASE}/v1/sessions?beta=true",
      headers: api_headers,
      body:    { agent: { type: "agent", id: AGENT_ID }, environment_id: ENVIRONMENT_ID }.to_json
    )
    res.parsed_response["id"]
  end

  def send_user_message(session_id, prompt)
    HTTParty.post(
      "#{API_BASE}/v1/sessions/#{session_id}/events?beta=true",
      headers: api_headers,
      body:    { events: [ { type: "user.message", content: [ { type: "text", text: prompt } ] } ] }.to_json
    )
  end

  def stream_events(session_id, sse)
    uri = URI("#{API_BASE}/v1/sessions/#{session_id}/events/stream?beta=true")
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 180) do |http|
      req = Net::HTTP::Get.new(uri)
      api_headers.each { |k, v| req[k] = v }

      http.request(req) do |res|
        partial = +""
        res.read_body do |chunk|
          partial += chunk
          while (pos = partial.index("\n\n"))
            forward_event(partial[0, pos], sse)
            partial = partial[pos + 2..]
          end
        end
      end
    end
  end

  def forward_event(block, sse)
    data_line = nil
    block.each_line do |line|
      data_line = line.chomp[6..] if line.start_with?("data: ")
    end
    return unless data_line

    begin
      event = JSON.parse(data_line)
      case event["type"]
      when "agent.message"
        event["content"]&.each do |blk|
          next unless blk["type"] == "text"
          sse.write("data: #{blk["text"].to_json}\n\n")
        end
      when "session.status_idle"
        sse.write("event: done\ndata: {}\n\n")
      when "session.error"
        msg = event.dig("error", "type") || "Research error"
        sse.write("event: error\ndata: #{msg.to_json}\n\n")
      end
    rescue JSON::ParseError
      # skip malformed lines
    end
  end

  def api_headers
    {
      "Content-Type"      => "application/json",
      "x-api-key"         => ENV.fetch("ANTHROPIC_API_KEY"),
      "anthropic-version" => "2023-06-01",
      "anthropic-beta"    => BETA_HEADER
    }
  end
end
