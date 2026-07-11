class PlacesController < ApplicationController
  def new
    @place = Place.new
  end

  def create
    @place = Place.new(place_params)

    begin
      @place.assign_coordinates_from_address
    rescue PlaceGeocoder::GeocodingError => e
      Rails.logger.error("[PlacesController] Geocoding failed: address=#{@place.address.inspect}, error=#{e.message}")
      @place.errors.add(:address, "が見つかりませんでした。住所を確認してください。")
      return render :new, status: :unprocessable_entity
    end

    if @place.save
      NotifySlackOfPlaceJob.perform_later(@place.id)
      redirect_to @place, notice: "会場を登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @place = Place.find_by!(public_uid: params[:public_uid])
    @events = @place.events.order(held_on: :desc)
  end

  private

  def place_params
    params.require(:place).permit(:name, :address)
  end
end
