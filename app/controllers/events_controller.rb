class EventsController < ApplicationController
  def new
    @event = Event.new
  end

  def create
    @event = Event.new(event_params)

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
    params.require(:event).permit(:title, :held_on, :url)
  end
end
