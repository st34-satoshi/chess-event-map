require "anthropic"

module Claude
  class EventExtractor
    class DetailResult < Anthropic::BaseModel
      required :title, String, doc: "大会名、例会名、またはイベント名。原則は日本語表記"
      required :held_on, String, doc: "開催日（YYYY-MM-DD）。複数日開催の場合は初日"
      required :place_name, String, nil?: true, doc: "会場名。不明な場合は null"
      required :place_address, String, nil?: true, doc: "会場の住所。不明な場合は null"
    end

    SYSTEM_PROMPT = <<~PROMPT.freeze
      チェス関連のイベント要項ページのHTMLから、イベント情報を抽出してください。
      主催は日本チェス連盟に限らず、チェスクラブや団体など任意の組織のイベントを対象とします。
      title は大会名・例会名・イベント名です。
      title は原則として日本語表記で返してください。h1 見出し、記事タイトル、概要の大会名など、HTML本文に日本語名がある場合は必ずその日本語名を使ってください。
      URLのスラッグや英語表記だけから title を推測しないでください（例: URLが caissa-pre-classic-rapid でも、h1が「Caissaプレクラシック・ラピッド大会」なら後者を使う）。
      日本語名がHTML本文のどこにも見つからない場合だけ、英語表記を使ってください。
      held_on は YYYY-MM-DD 形式で、複数日開催の場合は初日を使ってください。
      place_name は会場名です（例: きゅりあん（品川区総合区民会館））。
      既存の会場名一覧が渡された場合、HTMLの会場と同じ施設が一覧にあれば、一覧の名前をそのまま place_name に使ってください。
      表記ゆれ（略称・括弧の有無など）で同じ会場と判断できる場合も、一覧の名前を返してください。
      該当がなければHTMLに記載されている名前を返してください。
      place_address は住所です（例: 東京都品川区東大井5-18-1）。
      会場名や住所が明記されていない場合は null にしてください。
      推測で値を埋めないでください。
    PROMPT

    def self.extract(html, url:, existing_place_names: [])
      new.extract(html, url: url, existing_place_names: existing_place_names)
    end

    def extract(html, url:, existing_place_names: [])
      detail_url = normalize_url(url)
      raise Claude::Error, "invalid URL: #{url}" unless detail_url

      result = Client.request(
        system: SYSTEM_PROMPT,
        user: build_user_message(html, existing_place_names),
        format: DetailResult
      )

      held_on = parse_date(result.held_on)
      title = result.title.to_s.strip.presence
      place_name = resolve_place_name(result.place_name.to_s.strip.presence, existing_place_names)

      raise Claude::Error, "missing required detail fields" unless held_on && title

      {
        title: title,
        held_on: held_on,
        detail_url: detail_url,
        place_name: place_name,
        place_address: result.place_address.to_s.strip.presence
      }
    end

    private

    def build_user_message(html, existing_place_names)
      message = +""
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
