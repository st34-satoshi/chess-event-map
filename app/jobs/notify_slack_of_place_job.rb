class NotifySlackOfPlaceJob < ApplicationJob
  queue_as :default

  BASE_URL = "https://chess-event-map.stu345.com"

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
      緯度・経度: #{place.latitude}, #{place.longitude}
      #{BASE_URL}/places/#{place.public_uid}
    TEXT
  end
end
