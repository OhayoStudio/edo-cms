LexxyAssistant.configure do |c|
  c.system_prompt = Rails.root.join("docs/writing_guide.md").read
  c.adapter       = LexxyAssistant::Adapters::Claude.new(
    api_key:    ENV["ANTHROPIC_API_KEY"],
    model:      :"claude-opus-4-6",
    max_tokens: 16_000
  )
  c.before_action :require_authentication
end

Rails.application.config.to_prepare do
  LexxyAssistant::ApplicationController.include(Authentication)
end
