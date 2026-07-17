class XPost < ApplicationRecord
  include PublicUid

  belongs_to :x_account

  enum :event_detection_status, {
    pending: "pending",
    detected: "detected",
    # Deprecated: kept only so existing rows can still be read/migrated.
    # Use `no_event` instead — `not_detected` conflicted with the auto-generated
    # negative scope for `detected`. Run `rake import_x_post:migrate_not_detected_status`
    # to migrate remaining rows, then this value can be removed.
    not_detected: "not_detected",
    no_event: "no_event",
    already_exists: "already_exists",
    save_failed: "save_failed"
  }, default: "pending"

  validates :x_post_id, presence: true, uniqueness: true
  validates :text, presence: true
  validates :posted_at, presence: true
  validates :url,
    format: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    length: { maximum: 255 },
    allow_blank: true
end
