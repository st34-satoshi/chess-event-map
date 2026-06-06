class Request < ApplicationRecord
  belongs_to :correctable, polymorphic: true

  validates :comment, presence: true
end
