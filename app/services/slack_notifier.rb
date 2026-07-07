require "net/http"
require "uri"
require "json"

class SlackNotifier
  API_URL = "https://slack.com/api/chat.postMessage"

  def self.notify(text)
    token = Rails.application.credentials.slack_api_token
    channel = Rails.application.credentials.slack_channel
    if token.blank? || channel.blank?
      Sentry.capture_message(
        "Slack credentials are missing",
        level: :error,
        extra: {
          token_present: token.present?,
          channel_present: channel.present?
        }
      )
      return
    end

    uri = URI(API_URL)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Content-Type"] = "application/json; charset=utf-8"
    request.body = { channel: channel, text: text }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    body = JSON.parse(response.body)
    Rails.logger.error("Slack notification failed: #{body}") unless body["ok"]
  end
end
