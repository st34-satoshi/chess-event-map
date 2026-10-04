require "anthropic"
require "uri"

module Claude
  class WebsiteEventAnalyzer
    MAX_EVENTS = 20

    class EventItem < Anthropic::BaseModel
      required :title, String, doc: "大会名・例会名・イベント名。原則は日本語表記"
      required :held_on, String, doc: "開催日（YYYY-MM-DD）。複数日開催の場合は初日。年が不明な場合は実行日に近い年"
      required :place_name, String, nil?: true, doc: "会場名。不明な場合は null"
      required :place_address, String, nil?: true, doc: "会場の住所。不明な場合は null"
      required :detail_url, String, nil?: true, doc: "そのイベントの要項や詳細ページのURL。不明な場合は null"
    end

    class AnalysisResult < Anthropic::BaseModel
      required :events, Anthropic::ArrayOf[EventItem], doc: "ページに掲載されている今後開催のチェスイベント一覧"
    end

    def self.analyze(html, url:, existing_place_names: [])
      new.analyze(html, url: url, existing_place_names: existing_place_names)
    end

    def analyze(html, url:, existing_place_names: [])
      raise Claude::Error, "page content is blank" if html.blank?

      reference_date = Date.current
      result = Client.request(
        system: system_prompt(reference_date),
        user: build_user_message(html, url, existing_place_names, reference_date),
        format: AnalysisResult
      )

      Array(result.events).filter_map { |item| build_event(item, url, existing_place_names, reference_date) }
        .uniq { |event| [ event[:held_on], event[:title] ] }
        .first(MAX_EVENTS)
    end

    private

    def build_event(item, page_url, existing_place_names, reference_date)
      held_on = parse_held_on(item[:held_on], reference_date)
      title = item[:title].to_s.strip.presence
      return unless held_on && title
      return if held_on < reference_date

      {
        title: title,
        held_on: held_on,
        place_name: resolve_place_name(item[:place_name].to_s.strip.presence, existing_place_names),
        place_address: item[:place_address].to_s.strip.presence,
        detail_url: normalize_url(item[:detail_url], base: page_url)
      }
    end

    def parse_held_on(value, reference_date)
      HeldOn.parse(value, reference_date: reference_date)
    rescue Claude::Error
      nil
    end

    def system_prompt(reference_date)
      <<~PROMPT
        あなたは日本のチェスイベント情報を収集するアシスタントです。
        チェスクラブや団体のWebサイトのHTMLを読み、掲載されているチェスの大会・例会・イベントの開催情報をすべて抽出してください。
        events には、開催日が具体的に読み取れるイベントだけを入れてください。
        実行日（#{reference_date.iso8601}）より前に開催されたイベントや、結果報告・感想だけの記事は含めないでください。
        該当するイベントが無い場合は events を空配列にしてください。
        title は原則として日本語表記にしてください。HTML本文に日本語名がある場合は必ずその日本語名を使ってください。
        held_on は YYYY-MM-DD 形式で、複数日開催の場合は初日を使ってください。
        定期例会のように繰り返し開催されるものは、具体的な日付が書かれている回だけを1件ずつ返してください。
        年が明記されていない場合は、実行日（#{reference_date.iso8601}）に最も近い妥当な年を選んでください。
        通常は実行日と同じ年です。年末に来年の開催が案内されている場合など、実行日に近い来年を選んでください。
        実行日から半年以上離れる日付は選ばないでください。
        place_name は会場名です。
        既存の会場名一覧が渡された場合、ページの会場と同じ施設が一覧にあれば、一覧の名前をそのまま place_name に使ってください。
        表記ゆれ（略称・括弧の有無など）で同じ会場と判断できる場合も、一覧の名前を返してください。
        該当がなければページに記載されている名前を返してください。
        place_address は住所です（例: 東京都品川区東大井5-18-1）。
        detail_url は、そのイベント個別の要項や詳細ページへのリンクがある場合のみ返してください。相対URLのままでも構いません。
        不明な項目は null にしてください。推測で埋めないでください（開催年の補完を除く）。
      PROMPT
    end

    def build_user_message(html, url, existing_place_names, reference_date)
      message = +"実行日: #{reference_date.iso8601}\n"
      message << "ページURL: #{url}\n\n"
      names = Array(existing_place_names).map(&:to_s).reject(&:blank?)
      unless names.empty?
        message << "既存の会場名一覧:\n"
        names.each { |name| message << "- #{name}\n" }
        message << "\n"
      end
      message << "以下のHTMLからイベント情報を抽出してください:\n\n#{html}"
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

    def normalize_url(value, base:)
      url = value.to_s.strip
      return if url.blank?

      uri = URI.join(base.to_s, url)
      return unless uri.is_a?(URI::HTTP) && uri.host.present?

      uri.fragment = nil
      uri.to_s
    rescue URI::InvalidURIError, URI::BadURIError, ArgumentError
      nil
    end
  end
end
