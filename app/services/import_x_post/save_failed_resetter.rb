module ImportXPost
  class SaveFailedResetter
    def self.call
      new.call
    end

    def call
      scope = XPost.save_failed.where(posted_at: EventDetectionBatch::LOOKBACK.ago..)
      count = scope.count
      scope.update_all(event_detection_status: XPost.event_detection_statuses[:pending])
      count
    end
  end
end
