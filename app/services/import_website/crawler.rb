require "digest"

module ImportWebsite
  # Fetches one registered website, asks Claude for the upcoming events listed
  # on it, and registers the ones that are not on the map yet. Pages whose
  # content has not changed since the last successful crawl are skipped so
  # Claude is only called when something new may have been posted.
  class Crawler
    Result = Struct.new(:status, :website, :created, :existing, :errors, keyword_init: true)

    def self.call(website)
      new(website).call
    end

    def initialize(website)
      @website = website
    end

    def call
      response = ImportEvent::Client.fetch(@website.url)
      cleaned = ImportEvent::HtmlCleaner.clean(response.body)
      digest = Digest::SHA256.hexdigest(cleaned)

      if digest == @website.content_digest
        return finish!(:unchanged, created: [], existing: [], errors: [])
      end

      analyses = Claude::WebsiteEventAnalyzer.analyze(
        cleaned,
        url: response.url,
        existing_place_names: Place.order(:name).pluck(:name)
      )

      created = []
      existing = []
      errors = []
      analyses.each do |analysis|
        saved = EventSaver.call(analysis, fallback_url: response.url)
        (saved.status == :created ? created : existing) << saved.event
      rescue Claude::Error, ArgumentError, ImportEvent::Client::RequestError,
             PlaceGeocoder::GeocodingError, ActiveRecord::RecordInvalid => e
        errors << "#{analysis[:held_on]} #{analysis[:title]}: #{e.message}"
      end

      status = if errors.any?
        :failed
      elsif created.any?
        :event_created
      else
        :no_new_event
      end
      # Keep the old digest on failure so the page is analyzed again next time.
      finish!(status, created: created, existing: existing, errors: errors,
        digest: errors.empty? ? digest : @website.content_digest)
    rescue ImportEvent::Client::RequestError, Claude::Error => e
      finish!(:failed, created: [], existing: [], errors: [ e.message ], digest: @website.content_digest)
    end

    private

    def finish!(status, created:, existing:, errors:, digest: @website.content_digest)
      Rails.logger.warn("Website crawl failed for #{@website.url}: #{errors.join(' / ')}") if errors.any?

      @website.update!(
        content_digest: digest,
        last_crawled_at: Time.current,
        last_crawl_status: status,
        last_crawl_message: summary(created, existing, errors)
      )
      Result.new(status: status, website: @website, created: created, existing: existing, errors: errors)
    end

    def summary(created, existing, errors)
      lines = [ "created=#{created.size} already_exists=#{existing.size} failed=#{errors.size}" ]
      created.each { |event| lines << "created: #{event.held_on} #{event.title}" }
      errors.each { |error| lines << "failed: #{error}" }
      lines.join("\n")
    end
  end
end
