class XPost < ApplicationRecord
  include PublicUid

  belongs_to :x_account
end
