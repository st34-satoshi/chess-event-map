class Website < ApplicationRecord
  include PublicUid

  belongs_to :x_account, optional: true

  validates :name, presence: true
  validates :url,
    presence: true,
    uniqueness: true,
    format: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    length: { maximum: 255 }
end
