module ImportEvent
  class EventImporter
    Result = Struct.new(:status, :event, :place_created, keyword_init: true)

    def self.call(url:)
      new(url: url).call
    end

    def initialize(url:)
      @url = url
    end

    def call
      detail_url = normalize_url(@url)
      raise ArgumentError, "invalid URL: #{@url}" unless detail_url

      html = Client.get(detail_url)
      cleaned = HtmlCleaner.clean(html)
      existing_place_names = Place.order(:name).pluck(:name)
      detail = Claude::EventExtractor.extract(cleaned, url: detail_url, existing_place_names: existing_place_names)

      if Event.exists?(held_on: detail[:held_on], url: detail[:detail_url])
        event = Event.find_by!(held_on: detail[:held_on], url: detail[:detail_url])
        Rails.logger.info("Event already exists: #{event.title} (#{event.held_on})")
        return Result.new(status: :skipped, event: event, place_created: false)
      end

      unless detail[:place_name].present?
        raise ArgumentError, "venue name is missing"
      end

      place_name = detail[:place_name]
      existing_place = Place.find_by(name: place_name)

      if existing_place
        place = existing_place
        place_created = false
      else
        address = detail[:place_address].presence ||
          Claude::AddressInferrer.infer(place_name: place_name)
        unless address.present?
          raise ArgumentError, "geocodable address could not be determined for #{place_name}"
        end

        place, place_created = create_place!(name: place_name, address: address)
      end

      event = Event.create!(
        title: detail[:title],
        held_on: detail[:held_on],
        url: detail[:detail_url],
        place: place
      )

      Result.new(status: :created, event: event, place_created: place_created)
    end

    private

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

    def create_place!(name:, address:)
      place = Place.new(name: name, address: address)
      place.assign_coordinates_from_address
      place.save!
      [ place, true ]
    end
  end
end
