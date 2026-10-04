module ImportWebsite
  class CrawlBatch
    Result = Struct.new(:website_count, :counts, :results, keyword_init: true)

    def self.call(&block)
      new.call(&block)
    end

    def call(&block)
      websites = Website.active.includes(:x_account)
      website_count = websites.count
      SlackNotifier.notify("【チェスイベントマップ】Webサイトの巡回を開始します。対象: #{website_count}件")

      counts = Hash.new(0)
      results = []
      websites.find_each do |website|
        result = Crawler.call(website)
        counts[result.status] += 1
        results << result
        block&.call(result)
      end

      notify_finish(website_count, counts, results)
      Result.new(website_count: website_count, counts: counts, results: results)
    end

    private

    def notify_finish(website_count, counts, results)
      message = +"【チェスイベントマップ】Webサイトの巡回が完了しました。対象: #{website_count}件\n"
      message << %i[event_created no_new_event unchanged failed].map { |status| "#{status}: #{counts[status]}" }.join("\n")

      created = results.flat_map { |result| result.created.map { |event| "- #{event.held_on} #{event.title} (#{result.website.name})" } }
      message << "\n\n登録したイベント:\n#{created.join("\n")}" if created.any?

      failed = results.select { |result| result.errors.any? }
      if failed.any?
        lines = failed.map { |result| "- #{result.website.name} (#{result.website.url}): #{result.errors.join(' / ')}" }
        message << "\n\n失敗詳細:\n#{lines.join("\n")}"
      end

      SlackNotifier.notify(message)
    end
  end
end
