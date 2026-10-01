module XPostingHelper
  def with_x_credentials
    credentials = Rails.application.credentials
    original = credentials.method(:dig)
    credentials.define_singleton_method(:dig) do |*keys|
      values = { x: { oauth: { client_id: "client-id", client_secret: "client-secret",
        redirect_uri: "https://www.example.com/admin/x_posting/callback" }, mcp_token: "test-mcp-secret" } }
      keys.first == :x ? values.dig(*keys) : original.call(*keys)
    end
    yield
  ensure
    credentials.define_singleton_method(:dig, original)
  end

  def create_posting_account(id: "100", username: "announcer")
    account = XPostingAccount.new(x_user_id: id, username: username, name: "Chess Announcements")
    account.apply_tokens!(token_response)
    account
  end

  def token_response
    { "access_token" => "user-access-secret", "refresh_token" => "user-refresh-secret", "expires_in" => 7200,
      "scope" => XApi::UserClient::SCOPES.join(" ") }
  end

  def posting_path(action = nil)
    prefix = ActiveAdmin.application.default_namespace
    "/#{prefix}/x_posting#{action ? "/#{action}" : ''}"
  end
end
