require "test_helper"
require_relative "../support/x_posting_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  include XPostingHelper

  def rpc(method, params = {})
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: method, params: params }.to_json,
      headers: { "Authorization" => "Bearer test-mcp-secret", "Content-Type" => "application/json",
        "Accept" => "application/json, text/event-stream" }
  end

  test "requires a configured bearer credential and rejects foreign origins" do
    post "/mcp"
    assert_response :unauthorized
    with_x_credentials do
      post "/mcp", headers: { "Authorization" => "Bearer wrong" }
      assert_response :unauthorized
      post "/mcp", headers: { "Authorization" => "Bearer test-mcp-secret", "Origin" => "https://evil.example" }
      assert_response :forbidden
      post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
        headers: { "Authorization" => "Bearer test-mcp-secret", "Content-Type" => "application/json",
          "Accept" => "application/json, text/event-stream", "Origin" => "null" }
      assert_response :forbidden
    end
  end

  test "initializes and exposes tools without account selection or secrets" do
    with_x_credentials do
      rpc "initialize", { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "test", version: "1" } }
      assert_response :success
      assert_equal "chess-event-map", response.parsed_body.dig("result", "serverInfo", "name")
      rpc "tools/list"
      assert_response :success
      names = response.parsed_body.dig("result", "tools").map { |tool| tool["name"] }
      assert_equal %w[publish_event_to_x_tool x_posting_status_tool], names.sort
      rpc "tools/call", { name: "x_posting_status_tool", arguments: {} }
      assert_response :success
      assert_includes response.body, "posting_enabled"
      assert_not_includes response.body, "test-mcp-secret"
    end
  end

  test "MCP publishes selected account and rejects account overrides" do
    account = create_posting_account
    XPostingSetting.current.update!(x_posting_account: account)
    request = stub_request(:post, "https://api.x.com/2/tweets").to_return(status: 201, body: { data: { id: "777" } }.to_json)
    arguments = { event_uid: events(:one).public_uid, text: "Chess event", request_id: "mcp-request" }
    with_x_credentials do
      rpc "tools/call", { name: "publish_event_to_x_tool", arguments: arguments.merge(account_id: "unexpected") }
      assert_not_requested request
      rpc "tools/call", { name: "publish_event_to_x_tool", arguments: arguments }
      assert_response :success
      assert_not response.parsed_body.dig("result", "isError")
      assert_includes response.body, "https://x.com/i/web/status/777"
      assert_equal account, XPublication.last.x_posting_account
      rpc "tools/call", { name: "publish_event_to_x_tool", arguments: arguments }
      assert_requested request, times: 1
    end
  end

  test "tool errors are safe MCP error results" do
    with_x_credentials do
      rpc "tools/call", { name: "publish_event_to_x_tool", arguments: { event_uid: events(:one).public_uid, text: "Hello", request_id: "no-account" } }
      assert response.parsed_body.dig("result", "isError")
      assert_includes response.body, "No posting account selected"
    end
  end
  test "unsupported streams and session deletion return method not allowed" do
    with_x_credentials do
      get "/mcp", headers: { "Authorization" => "Bearer test-mcp-secret" }
      assert_response :method_not_allowed
      delete "/mcp", headers: { "Authorization" => "Bearer test-mcp-secret" }
      assert_response :method_not_allowed
    end
  end
end
