class PublishEventToXTool < MCP::Tool
  description "Publish an event announcement to X using ONLY the account selected by an admin. This makes a public post. Obtain the user's instruction to publish first. Supply the complete final text including any event URL. Reuse the same request_id and content when retrying; never change request_id to retry an uncertain result without checking X."
  input_schema(
    properties: {
      event_uid: { type: "string", minLength: 1, description: "Event public_uid from its Chess Event Map URL" },
      text: { type: "string", minLength: 1, maxLength: 25_000, description: "Final announcement; X enforces its weighted character limit" },
      request_id: { type: "string", minLength: 1, maxLength: 100, pattern: "^[a-zA-Z0-9_-]+$", description: "Unique ID for this publication, e.g. a UUID; retain for retries" }
    }, required: %w[event_uid text request_id], additionalProperties: false
  )
  annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true, open_world_hint: true)

  def self.call(event_uid:, text:, request_id:, server_context:)
    publication = XApi::Publisher.call(event_uid: event_uid, text: text, request_id: request_id)
    data = { status: publication.status, url: publication.post_url, request_id: publication.request_id,
      username: publication.x_posting_account.username }
    MCP::Tool::Response.new([ { type: "text", text: data.to_json } ])
  rescue XApi::Error => e
    MCP::Tool::Response.new([ { type: "text", text: e.message } ], error: true)
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    MCP::Tool::Response.new([ { type: "text", text: "Event not found or invalid publication parameters." } ], error: true)
  end
end
