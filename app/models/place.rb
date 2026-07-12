class Place < ApplicationRecord
  include PublicUid

  JAPAN_LATITUDE_RANGE = 24.0..46.0
  JAPAN_LONGITUDE_RANGE = 122.0..154.0

  has_many :events, dependent: :restrict_with_error
  has_many :requests, as: :correctable, dependent: :destroy

  after_create_commit :notify_slack_of_creation

  validates :name, presence: true, uniqueness: { message: "はすでに登録されています" }
  validates :address, presence: true, uniqueness: { message: "はすでに登録されています" }
  validates :latitude, :longitude, presence: true
  validate :coordinates_must_be_in_japan
  validate :coordinates_must_be_unique

  def assign_coordinates_from_address
    geocoded = PlaceGeocoder.lookup(address)
    assign_attributes(
      address: geocoded[:address],
      latitude: geocoded[:latitude],
      longitude: geocoded[:longitude]
    )
  end

  private

  def notify_slack_of_creation
    NotifySlackOfPlaceJob.perform_later(id)
  end

  def coordinates_must_be_in_japan
    return if latitude.blank? || longitude.blank?

    return if self.class.japan_coordinates?(latitude:, longitude:)

    errors.add(:base, "会場の緯度経度は日本国内である必要があります")
  end

  def self.japan_coordinates?(latitude:, longitude:)
    JAPAN_LATITUDE_RANGE.cover?(latitude.to_f) && JAPAN_LONGITUDE_RANGE.cover?(longitude.to_f)
  end

  def coordinates_must_be_unique
    return if latitude.blank? || longitude.blank?

    scope = self.class.where(latitude: latitude, longitude: longitude)
    scope = scope.where.not(id: id) if persisted?

    return unless scope.exists?

    errors.add(:base, "同じ緯度経度の会場はすでに登録されています")
  end
end
