class Event < ApplicationRecord
  include PublicUid

  belongs_to :place
  has_many :requests, as: :correctable, dependent: :destroy

  validates :title, presence: true
  validates :held_on, presence: true
  validates :url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true
end
