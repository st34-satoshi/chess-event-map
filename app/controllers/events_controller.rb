class EventsController < ApplicationController
  INDEX_LIMIT = 50

  def index
    @from = params.key?(:from) ? parse_date(params[:from]) : Date.current
    @to = parse_date(params[:to])

    events = Event.includes(:place).order(:held_on, :title)
    events = events.where(held_on: @from..) if @from
    events = events.where(held_on: ..@to) if @to

    limited_events = events.limit(INDEX_LIMIT + 1).to_a
    @events_truncated = limited_events.size > INDEX_LIMIT
    @events = limited_events.first(INDEX_LIMIT)
  end

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
