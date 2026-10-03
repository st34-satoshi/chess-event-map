class XPostingSetting < ApplicationRecord
  belongs_to :x_posting_account, optional: true

  def self.current
    find_or_create_by!(id: 1)
  end
end
