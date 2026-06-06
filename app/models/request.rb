class Request < ApplicationRecord
  belongs_to :correctable, polymorphic: true
end
