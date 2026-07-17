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

  desc "Detect and save events from pending X posts via Claude"
  task save_events: :environment do
    result = ImportXPost::EventDetectionBatch.call do |detection|
      line = "#{detection.status}: #{detection.x_post.public_uid} (@#{detection.x_post.x_account.at_name})"
      line = "#{line} — #{detection.error}" if detection.error.present?
      puts line
    end

    puts "Done. #{result.counts.map { |status, count| "#{status}=#{count}" }.join(' ')}"
  rescue Claude::Error, ActiveRecord::RecordInvalid => e
    SlackNotifier.notify("【チェスイベントマップ】X投稿のイベント調査が失敗しました。\n#{e.message}")
    abort "Save events failed: #{e.message}"
  end

  desc "Reset save_failed X posts from the last month back to pending"
  task reset_save_failed: :environment do
    count = ImportXPost::SaveFailedResetter.call
    puts "Done. reset=#{count}"
  end

  desc "Migrate X posts with the deprecated not_detected status to no_event"
  task migrate_not_detected_status: :environment do
    count = ImportXPost::NotDetectedStatusMigrator.call
    puts "Done. migrated=#{count}"
  end
end
