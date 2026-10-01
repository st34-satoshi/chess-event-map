module XApi
  class Publisher
    def self.call(event_uid:, text:, request_id:)
      new.call(event_uid: event_uid, text: text, request_id: request_id)
    end

    def call(event_uid:, text:, request_id:)
      event = Event.find_by!(public_uid: event_uid)
      existing = XPublication.find_by(request_id: request_id)
      return previous_result(existing, event, text) if existing

      # Persist the reservation before contacting X. Even a process crash must not
      # cause the same request to post again after an ambiguous network outcome.
      publication = XPublication.create!(event: event, text: text, request_id: request_id)
      error = nil
      setting = XPostingSetting.current
      setting.with_lock do
        account = setting.x_posting_account
        raise Error, "No posting account selected. Select one in the admin screen first." unless account

        publication.update!(x_posting_account: account)
        account.with_lock do
          account.apply_tokens!(UserClient.new.refresh(account.refresh_token)) if account.expires_at <= 1.minute.from_now
          begin
            post_id = UserClient.new.publish(token: account.access_token, text: text)
            publication.update!(status: "published", x_post_id: post_id)
          rescue Error => e
            # Commit rotated refresh tokens even when posting fails.
            error = e
            publication.update!(status: "failed", error_message: e.message)
          end
        end
      end
      raise error if error
      publication
    rescue ActiveRecord::RecordNotUnique
      previous_result(XPublication.find_by!(request_id: request_id), event, text)
    rescue Error => e
      publication.update!(status: "failed", error_message: e.message) if publication&.persisted? && publication.status == "pending"
      raise
    end

    private

    def previous_result(publication, event, text)
      if publication.event_id != event.id || publication.text != text
        raise Error, "This request ID was already used with different content."
      end
      return publication if publication.status == "published"
      raise Error, "This request is #{publication.status}; it will not be sent again. Check the publication history and X before using a new request ID."
    end
  end
end
