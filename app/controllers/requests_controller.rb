class RequestsController < ApplicationController
  CORRECTABLE_TYPES = %w[Place Event].freeze

  before_action :set_correctable, only: %i[new create]

  def new
    @request = @correctable.requests.build
  end

  def create
    @request = @correctable.requests.build(request_params)

    if @request.save
      NotifySlackOfRequestJob.perform_later(@request.id)
      redirect_to @correctable, notice: "修正依頼を送信しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_correctable
    type = params[:correctable_type]
    raise ActiveRecord::RecordNotFound unless type.in?(CORRECTABLE_TYPES)

    @correctable = type.constantize.find_by!(public_uid: params[:correctable_public_uid])
  end

  def request_params
    params.require(:request).permit(:comment)
  end
end
