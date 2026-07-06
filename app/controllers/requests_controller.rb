class RequestsController < ApplicationController
  CORRECTABLE_TYPES = { "Place" => Place, "Event" => Event }.freeze

  before_action :set_correctable, only: %i[new create]

  def new
    @request = @correctable.requests.build
  end

  def create
    @request = @correctable.requests.build(request_params)

    if @request.save
      redirect_to @correctable, notice: "修正依頼を送信しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_correctable
    klass = CORRECTABLE_TYPES[params[:correctable_type]]
    raise ActiveRecord::RecordNotFound unless klass

    @correctable = klass.find_by!(public_uid: params[:correctable_public_uid])
  end

  def request_params
    params.require(:request).permit(:comment)
  end
end
