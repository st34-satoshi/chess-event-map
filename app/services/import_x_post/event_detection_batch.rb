module ImportXPost
  class EventDetectionBatch
    LOOKBACK = 1.month

    Result = Struct.new(:pending_count, :counts, keyword_init: true)

    def self.call(&block)
      new.call(&block)
    end

    def call(&block)
      pending_posts = XPost.pending.where(posted_at: LOOKBACK.ago..)
      pending_count = pending_posts.count
      notify_start(pending_count)

      counts = Hash.new(0)
      pending_posts.find_each do |x_post|
        result = EventDetector.call(x_post)
        counts[result.status] += 1
        block&.call(result)
      end

      notify_finish(pending_count, counts)
      Result.new(pending_count: pending_count, counts: counts)
    end

    private

    def notify_start(pending_count)
      SlackNotifier.notify(
        "【チェスイベントマップ】X投稿のイベント調査を開始します。対象: #{pending_count}件"
      )
    end

    def notify_finish(pending_count, counts)
      summary = status_summary(counts)
      SlackNotifier.notify(
        "【チェスイベントマップ】X投稿のイベント調査が完了しました。対象: #{pending_count}件\n#{summary}"
      )
    end

    def status_summary(counts)
      statuses = %i[detected not_detected already_exists save_failed]
      lines = statuses.map { |status| "#{status}: #{counts[status]}" }
      lines.join("\n")
    end
  end
end
