require "anthropic"
require "uri"

module Claude
  class XPostEventAnalyzer
    class AnalysisResult < Anthropic::BaseModel
      required :has_event, Anthropic::Boolean, doc: "チェス関連のイベント開催情報が含まれていれば true"
      required :title, String, nil?: true, doc: "大会名・例会名・イベント名。原則は日本語表記"
      required :held_on, String, nil?: true, doc: "開催日（YYYY-MM-DD）。複数日開催の場合は初日。年が不明な場合は実行日に近い年"
      required :place_name, String, nil?: true, doc: "会場名。不明な場合は null"
      required :place_address, String, nil?: true, doc: "会場の住所。不明な場合は null"
      required :detail_url, String, nil?: true, doc: "要項や詳細ページのURL。不明な場合は null"
    end

    def self.analyze(text, existing_place_names: [])
      new.analyze(text, existing_place_names: existing_place_names)
    end

    def analyze(text, existing_place_names: [])
      raise Claude::Error, "post text is blank" if text.blank?

      reference_date = Date.current
      result = Client.request(
        system: system_prompt(reference_date),
        user: build_user_message(text, existing_place_names, reference_date),
        format: AnalysisResult
      )

      return { has_event: false } unless result.has_event

      held_on = HeldOn.parse(result[:held_on], reference_date: reference_date)
      title = result[:title].to_s.strip.presence
      detail_url = normalize_url(result[:detail_url])
      place_name = resolve_place_name(result[:place_name].to_s.strip.presence, existing_place_names)

      {
        has_event: true,
        title: title,
        held_on: held_on,
        place_name: place_name,
        place_address: result[:place_address].to_s.strip.presence,
        detail_url: detail_url
      }
    end

    private

    def system_prompt(reference_date)
      <<~PROMPT
        あなたは日本のチェスイベント情報を判定するアシスタントです。
        与えられたXの投稿本文を読み、チェスの大会・例会・イベントの開催情報が含まれているかを判定してください。
        has_event は、開催日や会場など具体的な開催情報が読み取れる場合のみ true にしてください。
        感想・結果報告・宣伝だけで開催情報が無い場合は false にしてください。
        has_event が true の場合、分かる範囲で title / held_on / place_name / place_address / detail_url を埋めてください。
        title は原則として日本語表記にしてください。
        held_on は YYYY-MM-DD 形式で、複数日開催の場合は初日を使ってください。
        年が明記されていない場合は、実行日（#{reference_date.iso8601}）に最も近い妥当な年を選んでください。
        通常は実行日と同じ年です。年末に来年の開催が案内されている場合など、実行日に近い来年を選んでください。
        実行日から半年以上離れる日付は選ばないでください。
        place_name は会場名です。
        既存の会場名一覧が渡された場合、投稿の会場と同じ施設が一覧にあれば、一覧の名前をそのまま place_name に使ってください。
        表記ゆれ（略称・括弧の有無など）で同じ会場と判断できる場合も、一覧の名前を返してください。
        該当がなければ投稿に記載されている名前を返してください。
        detail_url は要項や詳細が載っている http/https のURLがある場合のみ返してください。
        不明な項目は null にしてください。推測で埋めないでください（開催年の補完を除く）。
        has_event が false の場合、他の項目はすべて null にしてください。
      PROMPT
    end

    def build_user_message(text, existing_place_names, reference_date)
      message = +"実行日: #{reference_date.iso8601}\n\n"
      names = Array(existing_place_names).map(&:to_s).reject(&:blank?)
      unless names.empty?
        message << "既存の会場名一覧:\n"
        names.each { |name| message << "- #{name}\n" }
        message << "\n"
      end
      message << "以下のX投稿を判定してください:\n\n#{text}"
      message
    end

    def resolve_place_name(name, existing_place_names)
      return if name.blank?

      names = Array(existing_place_names).map(&:to_s).reject(&:blank?)
      return name if names.empty?

      names.find { |existing| existing == name } ||
        names.find { |existing| existing.casecmp?(name) } ||
        name
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
