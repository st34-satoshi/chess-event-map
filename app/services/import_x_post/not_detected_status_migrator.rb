module ImportXPost
  class NotDetectedStatusMigrator
    def self.call
      new.call
    end

    def call
      scope = XPost.not_detected
      count = scope.count
      scope.update_all(event_detection_status: XPost.event_detection_statuses[:no_event])
      count
    end
  end
end
