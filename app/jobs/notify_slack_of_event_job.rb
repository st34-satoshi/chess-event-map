class NotifySlackOfEventJob < ApplicationJob
  queue_as :default

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
      #{event_url_line(event)}#{app_base_url}/events/#{event.public_uid}
    TEXT
  end

  def event_url_line(event)
    return "" if event.url.blank?

    "URL: #{event.url}\n"
  end
end
