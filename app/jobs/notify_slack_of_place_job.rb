class NotifySlackOfPlaceJob < ApplicationJob
  queue_as :default

  def perform(place_id)
    place = Place.find_by(id: place_id)
    return unless place

    SlackNotifier.notify(build_message(place))
  end

  private

  def build_message(place)
    <<~TEXT.chomp
      【チェスイベントマップ】新しい会場が追加されました。
      会場名: #{place.name}
      住所: #{place.address}
    TEXT
  end
end
