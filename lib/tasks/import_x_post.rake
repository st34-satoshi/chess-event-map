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
end
