module ImportWebsite
  # Saves one event found on a website. Uses the fields Claude read from the
  # listing page when they are complete, and falls back to reading the event's
  # detail page when the venue is missing.
  class EventSaver
    Result = Struct.new(:status, :event, keyword_init: true)

    def self.call(analysis, fallback_url:)
      new(analysis, fallback_url: fallback_url).call
    end

    def initialize(analysis, fallback_url:)
      @analysis = analysis
      @fallback_url = fallback_url
    end

    def call
      detail_url = @analysis[:detail_url]

      if detail_url.present? && (event = Event.find_by(held_on: @analysis[:held_on], url: detail_url))
        return Result.new(status: :already_exists, event: event)
      end

      if @analysis[:place_name].present?
        save_from_analysis(url: detail_url.presence || @fallback_url)
      elsif detail_url.present? && detail_url != @fallback_url
        import_from_detail_page(detail_url)
      else
        raise ArgumentError, "venue name is missing"
      end
    end

    private

    def save_from_analysis(url:)
      place, = ImportEvent::PlaceResolver.find_or_create!(
        name: @analysis[:place_name],
        address: @analysis[:place_address]
      )

      if (event = Event.find_by(held_on: @analysis[:held_on], place_id: place.id))
        return Result.new(status: :already_exists, event: event)
      end

      event = Event.create!(
        title: @analysis[:title],
        held_on: @analysis[:held_on],
        url: url,
        place: place,
        created_by: :ai
      )
      Result.new(status: :created, event: event)
    end

    def import_from_detail_page(detail_url)
      result = ImportEvent::EventImporter.call(url: detail_url)
      Result.new(status: result.status == :created ? :created : :already_exists, event: result.event)
    end
  end
end
