module ImportXPost
  class EventDetector
    Result = Struct.new(:status, :x_post, :event, :place_created, :error, keyword_init: true)

    def self.call(x_post)
      new(x_post).call
    end

    def initialize(x_post)
      @x_post = x_post
    end

    def call
      existing_place_names = Place.order(:name).pluck(:name)
      analysis = Claude::XPostEventAnalyzer.analyze(
        @x_post.text,
        existing_place_names: existing_place_names
      )

      unless analysis[:has_event]
        @x_post.no_event!
        return Result.new(status: :no_event, x_post: @x_post)
      end

      if analysis[:detail_url].present?
        import_from_url(analysis[:detail_url])
      else
        import_from_analysis(analysis)
      end
    rescue Claude::Error, ArgumentError, ImportEvent::Client::RequestError,
           PlaceGeocoder::GeocodingError, ActiveRecord::RecordInvalid => e
      fail_save!(e.message)
    end

    private

    def import_from_url(detail_url)
      result = ImportEvent::EventImporter.call(url: detail_url)

      case result.status
      when :created
        @x_post.detected!
        Result.new(status: :detected, x_post: @x_post, event: result.event, place_created: result.place_created)
      when :skipped
        @x_post.already_exists!
        Result.new(status: :already_exists, x_post: @x_post, event: result.event, place_created: false)
      else
        fail_save!("unexpected import status: #{result.status}")
      end
    end

    def import_from_analysis(analysis)
      unless analysis[:title].present? && analysis[:held_on].present? && analysis[:place_name].present?
        raise ArgumentError, "event fields are incomplete: title=#{analysis[:title].inspect} held_on=#{analysis[:held_on].inspect} place_name=#{analysis[:place_name].inspect}"
      end

      place, place_created = find_or_create_place!(
        name: analysis[:place_name],
        address: analysis[:place_address]
      )

      if Event.exists?(held_on: analysis[:held_on], place_id: place.id)
        event = Event.find_by!(held_on: analysis[:held_on], place_id: place.id)
        @x_post.already_exists!
        return Result.new(status: :already_exists, x_post: @x_post, event: event, place_created: false)
      end

      event = Event.create!(
        title: analysis[:title],
        held_on: analysis[:held_on],
        url: @x_post.url,
        place: place,
        created_by: :ai
      )

      @x_post.detected!
      Result.new(status: :detected, x_post: @x_post, event: event, place_created: place_created)
    end

    def find_or_create_place!(name:, address:)
      existing_place = Place.find_by(name: name)
      return [ existing_place, false ] if existing_place

      resolved_address = address.presence || Claude::AddressInferrer.infer(place_name: name)
      raise ArgumentError, "geocodable address could not be determined for #{name}" if resolved_address.blank?

      place = Place.new(name: name, address: resolved_address, created_by: :ai)
      place.assign_coordinates_from_address

      existing = Place.find_by(latitude: place.latitude, longitude: place.longitude)
      return [ existing, false ] if existing

      place.save!
      [ place, true ]
    end

    def fail_save!(message)
      Rails.logger.warn("XPost event detection failed for #{@x_post.public_uid}: #{message}")
      @x_post.save_failed!
      Result.new(status: :save_failed, x_post: @x_post, error: message)
    end
  end
end
