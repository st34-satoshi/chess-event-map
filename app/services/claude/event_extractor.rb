require "anthropic"

module Claude
  class EventExtractor
    class DetailResult < Anthropic::BaseModel
      required :title, String, doc: "大会名、例会名、またはイベント名"
      required :held_on, String, doc: "開催日（YYYY-MM-DD）。複数日開催の場合は初日"
      required :place_name, String, nil?: true, doc: "会場名。不明な場合は null"
      required :place_address, String, nil?: true, doc: "会場の住所。不明な場合は null"
    end

    SYSTEM_PROMPT = <<~PROMPT.freeze
      チェス関連のイベント要項ページのHTMLから、イベント情報を抽出してください。
      主催は日本チェス連盟に限らず、チェスクラブや団体など任意の組織のイベントを対象とします。
      title は大会名・例会名・イベント名など、ページに記載されている正式名称です。
      held_on は YYYY-MM-DD 形式で、複数日開催の場合は初日を使ってください。
      place_name は会場名です（例: きゅりあん（品川区総合区民会館））。
      place_address は住所です（例: 東京都品川区東大井5-18-1）。
      会場名や住所が明記されていない場合は null にしてください。
      推測で値を埋めないでください。
    PROMPT

    def self.extract(html, url:)
      new.extract(html, url: url)
    end

    def extract(html, url:)
      detail_url = normalize_url(url)
      raise Error, "invalid URL: #{url}" unless detail_url

      result = Client.request(
        system: SYSTEM_PROMPT,
        user: "以下のHTMLからイベント情報を抽出してください:\n\n#{html}",
        format: DetailResult
      )

      held_on = parse_date(result.held_on)
      title = result.title.to_s.strip.presence

      raise Error, "missing required detail fields" unless held_on && title

      {
        title: title,
        held_on: held_on,
        detail_url: detail_url,
        place_name: result.place_name.to_s.strip.presence,
        place_address: result.place_address.to_s.strip.presence
      }
    end

    private

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error, TypeError
      nil
    end

    def normalize_url(value)
      url = value.to_s.strip
      return if url.blank?

      uri = URI.parse(url)
      return unless uri.is_a?(URI::HTTP) && uri.host.present?

      uri.fragment = nil
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end
  end
end
