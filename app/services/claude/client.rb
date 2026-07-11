require "anthropic"

module Claude
  class Error < StandardError; end

  class Client
    MODEL = "claude-haiku-4-5-20251001"
    MAX_TOKENS = 8192

    def self.request(user:, format:, system:)
      message = client.messages.create(
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: system,
        messages: [ { role: "user", content: user } ],
        output_config: { format: format }
      )

      parsed = message.parsed_output
      raise Error, "Claude returned no structured output" if parsed.nil?
      raise Error, "Claude structured output parse failed: #{parsed[:error]}" if parsed.is_a?(Hash) && parsed[:error]

      parsed
    rescue Anthropic::Errors::Error => e
      raise Error, e.message
    end

    def self.client
      api_key = Rails.application.credentials.dig(:anthropic, :api_key)
      raise Error, "Anthropic API key is missing" if api_key.blank?

      @client ||= Anthropic::Client.new(api_key: api_key)
    end
  end
end
