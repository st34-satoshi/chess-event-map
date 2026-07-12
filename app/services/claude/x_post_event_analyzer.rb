require "anthropic"
require "uri"

module Claude
  class XPostEventAnalyzer
    class AnalysisResult < Anthropic::BaseModel
      required :has_event, Anthropic::Boolean, doc: "チェス関連のイベント開催情報が含まれていれば true"
      required :title, String, nil?: true, doc: "大会名・例会名・イベント名。原則は日本語表記"
      required :held_on, String, nil?: true, doc: "開催日（YYYY-MM-DD）。複数日開催の場合は初日"
      required :place_name, String, nil?: true, doc: "会場名。不明な場合は null"
      required :place_address, String, nil?: true, doc: "会場の住所。不明な場合は null"
      required :detail_url, String, nil?: true, doc: "要項や詳細ページのURL。不明な場合は null"
    end

    SYSTEM_PROMPT = <<~PROMPT.freeze
      あなたは日本のチェスイベント情報を判定するアシスタントです。
      与えられたXの投稿本文を読み、チェスの大会・例会・イベントの開催情報が含まれているかを判定してください。
      has_event は、開催日や会場など具体的な開催情報が読み取れる場合のみ true にしてください。
      感想・結果報告・宣伝だけで開催情報が無い場合は false にしてください。
      has_event が true の場合、分かる範囲で title / held_on / place_name / place_address / detail_url を埋めてください。
      title は原則として日本語表記にしてください。
      held_on は YYYY-MM-DD 形式で、複数日開催の場合は初日を使ってください。
      detail_url は要項や詳細が載っている http/https のURLがある場合のみ返してください。
      不明な項目は null にしてください。推測で埋めないでください。
      has_event が false の場合、他の項目はすべて null にしてください。
    PROMPT

    def self.analyze(text)
      new.analyze(text)
    end

    def analyze(text)
      raise Claude::Error, "post text is blank" if text.blank?

      result = Client.request(
        system: SYSTEM_PROMPT,
        user: "以下のX投稿を判定してください:\n\n#{text}",
        format: AnalysisResult
      )

      return { has_event: false } unless result.has_event

      held_on = parse_date(result.held_on)
      title = result.title.to_s.strip.presence
      detail_url = normalize_url(result.detail_url)

      {
        has_event: true,
        title: title,
        held_on: held_on,
        place_name: result.place_name.to_s.strip.presence,
        place_address: result.place_address.to_s.strip.presence,
        detail_url: detail_url
      }
    end

    private

    def parse_date(value)
      return if value.blank?

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
