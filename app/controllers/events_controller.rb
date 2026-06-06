class EventsController < ApplicationController
  def new
    @event = Event.new(place_id: params[:place_id])
    @places = Place.order(:name)
  end

  def create
    @event = Event.new(event_params)
    @places = Place.order(:name)

    if @event.save
      redirect_to @event, notice: "イベントを登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @event = Event.find_by!(public_uid: params[:public_uid])
  end

  private

  def event_params
    params.require(:event).permit(:title, :held_on, :url, :place_id)
  end
end
