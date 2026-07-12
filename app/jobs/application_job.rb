class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  def self.app_base_url
    if Rails.env.development?
      "http://localhost:3066"
    else
      "https://chess-event-map.stu345.com"
    end
  end

  def app_base_url
    self.class.app_base_url
  end
end
