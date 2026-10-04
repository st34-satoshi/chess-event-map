namespace :import_website do
  desc "Crawl active websites and save new events via Claude"
  task crawl: :environment do
    result = ImportWebsite::CrawlBatch.call do |crawl|
      line = "#{crawl.status}: #{crawl.website.name} (#{crawl.website.url}) created=#{crawl.created.size} already_exists=#{crawl.existing.size}"
      line = "#{line} — #{crawl.errors.join(' / ')}" if crawl.errors.any?
      puts line
    end

    puts "Done. #{result.counts.map { |status, count| "#{status}=#{count}" }.join(' ')}"
  rescue ActiveRecord::RecordInvalid => e
    SlackNotifier.notify("【チェスイベントマップ】Webサイトの巡回が失敗しました。\n#{e.message}")
    abort "Crawl failed: #{e.message}"
  end
end
