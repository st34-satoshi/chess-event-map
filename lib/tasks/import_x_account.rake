namespace :import_x_account do
  desc "Import X accounts from CSV (CSV_PATH=db/data/x_accounts.csv)"
  task csv: :environment do
    path = ENV["CSV_PATH"].presence || ImportXAccount::CsvImporter::DEFAULT_PATH
    result = ImportXAccount::CsvImporter.call(path: path)

    result.created.each do |account|
      puts "Created: @#{account.at_name} (x_user_id=#{account.x_user_id}, #{account.public_uid})"
    end
    result.skipped.each do |at_name|
      puts "Skipped existing: @#{at_name}"
    end

    puts "Done. created=#{result.created.size} skipped=#{result.skipped.size}"
  rescue Errno::ENOENT
    abort "CSV not found: #{path}"
  rescue XApi::Error, ActiveRecord::RecordInvalid => e
    abort "Import failed: #{e.message}"
  end
end
