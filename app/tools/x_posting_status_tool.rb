class XPostingStatusTool < MCP::Tool
  description "Read the admin-selected X posting account. No tokens are returned."
  input_schema(properties: {}, additionalProperties: false)
  annotations(read_only_hint: true, destructive_hint: false, open_world_hint: false)

  def self.call(server_context:)
    account = XPostingSetting.current.x_posting_account
    data = { posting_enabled: account.present?, username: account&.username, x_user_id: account&.x_user_id }
    MCP::Tool::Response.new([ { type: "text", text: data.to_json } ])
  end
end
