class NotifySlackOfEventJob < ApplicationJob
  queue_as :default

  BASE_URL = "https://chess-event-map.stu345.com"

  def perform(event_id)
    event = Event.find_by(id: event_id)
    return unless event

    SlackNotifier.notify(build_message(event))
  end

  private

  def build_message(event)
    <<~TEXT.chomp
      【チェスイベントマップ】新しいイベントが追加されました。
      イベント名: #{event.title}
      開催日: #{event.held_on}
      会場: #{event.place.name}
      #{BASE_URL}/events/#{event.public_uid}
    TEXT
  end
end
