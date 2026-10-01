class McpController < ActionController::API
  before_action :authenticate_mcp!
  before_action :validate_origin!

  def create
    return head :method_not_allowed unless request.post?

    server = MCP::Server.new(name: "chess-event-map", version: "1.0.0",
      tools: [ XPostingStatusTool, PublishEventToXTool ])
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(server,
      stateless: true, enable_json_response: true, serve_subscriptions_listen: false,
      allowed_hosts: [ URI(Rails.application.credentials.dig(:x, :oauth, :redirect_uri)).host ])
    status, headers, body = transport.handle_request(request)
    self.status = status
    headers.each { |key, value| response.set_header(key, value) }
    self.response_body = body
  end

  private

  def authenticate_mcp!
    expected = Rails.application.credentials.dig(:x, :mcp_token)
    supplied = request.headers["Authorization"].to_s.delete_prefix("Bearer ")
    unless expected.present? && request.headers["Authorization"].to_s.start_with?("Bearer ") &&
        ActiveSupport::SecurityUtils.secure_compare(expected, supplied)
      response.set_header("WWW-Authenticate", 'Bearer realm="chess-event-map"')
      head :unauthorized
    end
  end

  def validate_origin!
    origin = request.headers["Origin"]
    allowed = Rails.application.credentials.dig(:x, :oauth, :redirect_uri)
    unless allowed.present?
      return head :service_unavailable
    end
    uri = URI(allowed)
    expected_origin = "#{uri.scheme}://#{uri.host}#{uri.port == uri.default_port ? '' : ":#{uri.port}"}"
    head :forbidden if origin.present? && origin != expected_origin
  end
end
