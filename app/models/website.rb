class Website < ApplicationRecord
  include PublicUid

  belongs_to :x_account, optional: true

  enum :last_crawl_status, {
    unchanged: "unchanged",
    event_created: "event_created",
    no_new_event: "no_new_event",
    failed: "failed"
  }, prefix: :crawl, validate: { allow_nil: true }

  scope :active, -> { where(active: true) }

  validates :name, presence: true
  validates :url,
    presence: true,
    uniqueness: true,
    format: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    length: { maximum: 255 }
end
