namespace :import_event do
  desc "Import event from a URL (URL=... or rake import_event:url[https://...])"
  task :url, [ :url ] => :environment do |_task, args|
    url = args[:url].presence || ENV["URL"]
    abort "URL is required. Example: URL=https://japanchess.org/2026/05/summer2026-2/ bin/rails import_event:url" if url.blank?

    result = ImportEvent::EventImporter.call(url: url)

    case result.status
    when :created
      puts "Created event: #{result.event.title} (#{result.event.held_on})"
      puts "  public_uid: #{result.event.public_uid}"
      puts "  place: #{result.event.place.name}"
      puts "  url:   #{result.event.url}"
      puts "  place_created: #{result.place_created}"
    when :skipped
      puts "Skipped existing event: #{result.event.title} (#{result.event.held_on})"
      puts "  public_uid: #{result.event.public_uid}"
      puts "  url: #{result.event.url}"
    end
  rescue ArgumentError, ImportEvent::Client::RequestError, Claude::Error,
         PlaceGeocoder::GeocodingError, ActiveRecord::RecordInvalid => e
    abort "Import failed: #{e.message}"
  end
end
