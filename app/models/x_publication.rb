class XPublication < ApplicationRecord
  belongs_to :event
  belongs_to :x_posting_account, optional: true

  validates :request_id, presence: true, length: { maximum: 100 }, format: { with: /\A[a-zA-Z0-9_-]+\z/ }
  validates :text, presence: true, length: { maximum: 25_000 }
  validate :text_fits_storage
  validates :status, inclusion: { in: %w[pending published failed] }

  def post_url
    "https://x.com/i/web/status/#{x_post_id}" if x_post_id.present?
  end

  private

  def text_fits_storage
    errors.add(:text, "is too large") if text && text.bytesize > 65_535
  end
end
