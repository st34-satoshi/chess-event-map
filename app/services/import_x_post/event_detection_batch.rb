module ImportXPost
  class EventDetectionBatch
    LOOKBACK = 1.month

    Result = Struct.new(:pending_count, :counts, :errors, keyword_init: true)

    def self.call(&block)
      new.call(&block)
    end

    def call(&block)
      pending_posts = XPost.pending.where(posted_at: LOOKBACK.ago..)
      pending_count = pending_posts.count
      notify_start(pending_count)

      counts = Hash.new(0)
      errors = []
      pending_posts.find_each do |x_post|
        result = EventDetector.call(x_post)
        counts[result.status] += 1
        errors << result if result.status == :save_failed && result.error.present?
        block&.call(result)
      end

      notify_finish(pending_count, counts, errors)
      Result.new(pending_count: pending_count, counts: counts, errors: errors)
    end

    private

    def notify_start(pending_count)
      SlackNotifier.notify(
        "【チェスイベントマップ】X投稿のイベント調査を開始します。対象: #{pending_count}件"
      )
    end

    def notify_finish(pending_count, counts, errors)
      message = +"【チェスイベントマップ】X投稿のイベント調査が完了しました。対象: #{pending_count}件\n"
      message << status_summary(counts)
      message << "\n\n#{error_summary(errors)}" if errors.any?
      SlackNotifier.notify(message)
    end

    def status_summary(counts)
      statuses = %i[detected no_event already_exists save_failed]
      lines = statuses.map { |status| "#{status}: #{counts[status]}" }
      lines.join("\n")
    end

    def error_summary(errors)
      lines = [ "失敗詳細:" ]
      errors.each do |result|
        x_post = result.x_post
        lines << "- #{x_post.public_uid} (@#{x_post.x_account.at_name}): #{result.error}"
      end
      lines.join("\n")
    end
  end
end
