require "anthropic"

module Claude
  class AddressInferrer
    class AddressResult < Anthropic::BaseModel
      required :address, String, nil?: true, doc: "geocoding.jp で検索できる日本語の住所"
    end

    SYSTEM_PROMPT = <<~PROMPT.freeze
      会場名から、geocoding.jp で緯度経度を取得できる日本語の住所文字列を推定してください。
      番地まで分かる場合は番地まで含めてください（例: 東京都品川区東大井5-18-1）。
      番地まで分からない場合は null にしてください。
      推定できない場合は null にしてください。
    PROMPT

    def self.infer(place_name:)
      new.infer(place_name: place_name)
    end

    def infer(place_name:)
      result = Client.request(
        system: SYSTEM_PROMPT,
        user: "会場名: #{place_name}\n\nこの会場の geocoding 用住所を返してください。",
        format: AddressResult
      )

      result.address.to_s.strip.presence
    end
  end
end
