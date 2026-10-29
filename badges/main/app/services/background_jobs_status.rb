# What the Solid Queue job runner is doing, for the Background jobs section on Data health.
class BackgroundJobsStatus
  SLOW_AFTER = 15.minutes
  STUCK_AFTER = 1.hour
  # Raised by Solid Queue for jobs a runner had claimed when it died; they never retry on their own.
  INTERRUPTED_ERRORS = %w[ProcessPrunedError ProcessMissingError ProcessExitError ThreadTerminatedError].freeze

  JOB_LABELS = {
    "NotificationMailerJob" => "Portal emails",
    "ActionMailer::MailDeliveryJob" => "Other emails",
    "Pay::Webhooks::ProcessJob" => "Stripe payment updates",
    "ActiveStorage::AnalyzeJob" => "File processing",
    "ActiveStorage::PurgeJob" => "File cleanup",
    "Ahoy::GeocodeV2Job" => "Visitor locations",
    "SolidQueue::RecurringJob" => "Scheduled tasks"
  }.freeze

  def self.label_for(class_name)
    JOB_LABELS.fetch(class_name) { class_name.demodulize.underscore.humanize }
  end

  def self.available?
    ENV["SOLID_QUEUE_IN_PUMA"].present?
  end

  def light
    return :red if !runner_alive? || waiting_longer_than?(STUCK_AFTER)
    return :yellow if waiting_longer_than?(SLOW_AFTER) || interrupted_count.positive?

    :green
  end

  def runner_alive?
    return @runner_alive if defined?(@runner_alive)

    @runner_alive = JobRunnerHealth.alive?
  end

  def last_worker_heartbeat_at
    JobRunnerHealth.last_worker_heartbeat_at
  end

  def waiting_count
    @waiting_count ||= SolidQueue::ReadyExecution.count
  end

  def oldest_waiting_at
    @oldest_waiting_at ||= SolidQueue::ReadyExecution.minimum(:created_at)
  end

  def waiting_by_job
    SolidQueue::Job.joins(:ready_execution).group(:class_name).count.sort_by { |_name, count| -count }.to_h
  end

  def failed_last_day_count
    SolidQueue::FailedExecution.where(created_at: 1.day.ago..).count
  end

  def interrupted_count
    @interrupted_count ||= interrupted.count
  end

  def retry_interrupted!
    interrupted.includes(:job).find_each.count(&:retry)
  end

  private

  def waiting_longer_than?(duration)
    oldest_waiting_at.present? && oldest_waiting_at < duration.ago
  end

  # `error` is JSON-serialized, so an Arel match would encode the pattern; compare the raw text.
  def interrupted
    patterns = INTERRUPTED_ERRORS.map { |name| "%Processes::#{name}%" }
    SolidQueue::FailedExecution.where(([ "error LIKE ?" ] * patterns.size).join(" OR "), *patterns)
  end
end
