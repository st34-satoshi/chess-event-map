class NotifySlackOfRequestJob < ApplicationJob
  queue_as :default

  def perform(request_id)
    request = Request.find_by(id: request_id)
    return unless request

    SlackNotifier.notify(build_message(request))
  end

  private

  def build_message(request)
    correctable = request.correctable
    target_name = correctable.respond_to?(:title) ? correctable.title : correctable.name

    <<~TEXT.chomp
      修正依頼が届きました。
      対象: #{correctable.class.name}「#{target_name}」
      内容: #{request.comment}
    TEXT
  end
end
