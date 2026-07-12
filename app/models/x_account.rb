class XAccount < ApplicationRecord
  include PublicUid

  validates :at_name, presence: true, uniqueness: true
  validates :x_user_id, presence: true, uniqueness: true
  validates :profile_image_url,
    format: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    length: { maximum: 255 },
    allow_blank: true
end
