class ClaudeWritingService
  GUIDE_PATH = Rails.root.join("docs/writing_guide.md").freeze

  def self.system_prompt
    @system_prompt ||= GUIDE_PATH.read
  end

  def stream(prompt, &block)
    client   = Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
    msg_stream = client.messages.stream(
      model:      :"claude-opus-4-6",
      max_tokens: 16_000,
      system_:    [ { type: "text", text: self.class.system_prompt, cache_control: { type: "ephemeral" } } ],
      messages:   [ { role: "user", content: prompt } ]
    )
    msg_stream.text.each { |chunk| block.call(chunk) }
    msg_stream.accumulated_message.usage
  end
end
