class Event < ApplicationRecord
  include PublicUid
  include CreatedBySource

  belongs_to :place
  has_many :requests, as: :correctable, dependent: :destroy

  after_create_commit :notify_slack_of_creation

  validates :title, presence: true
  validates :held_on, presence: true
  validates :url,
    format: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    length: { maximum: 255 },
    allow_blank: true

  private

  def notify_slack_of_creation
    NotifySlackOfEventJob.perform_later(id)
  end
end
