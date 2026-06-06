module PublicUid
  extend ActiveSupport::Concern

  PUBLIC_UID_LENGTH = 12

  included do
    before_validation :assign_public_uid, on: :create
    validates :public_uid, presence: true, uniqueness: true
  end

  def to_param
    public_uid
  end

  private

  def assign_public_uid
    return if public_uid.present?

    loop do
      self.public_uid = SecureRandom.alphanumeric(PUBLIC_UID_LENGTH)
      break unless self.class.exists?(public_uid: public_uid)
    end
  end
end
