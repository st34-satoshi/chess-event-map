class XPost < ApplicationRecord
  include PublicUid

  belongs_to :x_account

  enum :event_detection_status, {
    pending: "pending",
    detected: "detected",
    not_detected: "not_detected"
  }, default: "pending"

  validates :x_post_id, presence: true, uniqueness: true
  validates :text, presence: true
  validates :posted_at, presence: true
  validates :url,
    format: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    length: { maximum: 255 },
    allow_blank: true
end
