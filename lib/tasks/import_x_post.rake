namespace :import_x_post do
  desc "Fetch and save posts for all X accounts"
  task fetch: :environment do
    result = ImportXPost::Importer.call

    result.created.each do |post|
      puts "Created: @#{post.x_account.at_name} #{post.x_post_id} (#{post.public_uid})"
    end
    result.skipped.each do |x_post_id|
      puts "Skipped existing: #{x_post_id}"
    end

    puts "Done. created=#{result.created.size} skipped=#{result.skipped.size}"
  rescue XApi::Error, ActiveRecord::RecordInvalid => e
    abort "Import failed: #{e.message}"
  end

  desc "Detect events in pending X posts via Claude"
  task detect_events: :environment do
    counts = Hash.new(0)

    XPost.pending.find_each do |x_post|
      result = ImportXPost::EventDetector.call(x_post)
      counts[result.status] += 1
      puts "#{result.status}: #{x_post.public_uid} (@#{x_post.x_account.at_name})"
    end

    puts "Done. #{counts.map { |status, count| "#{status}=#{count}" }.join(' ')}"
  rescue Claude::Error, ActiveRecord::RecordInvalid => e
    abort "Detection failed: #{e.message}"
  end
end
