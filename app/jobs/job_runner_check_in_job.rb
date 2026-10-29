# Pings a Honeybadger check-in, which alerts when the pings stop because no worker is running jobs.
class JobRunnerCheckInJob < ApplicationJob
  queue_as :default

  def perform
    check_in_id = ENV["HONEYBADGER_JOB_RUNNER_CHECK_IN_ID"].presence
    return unless check_in_id

    Honeybadger.check_in(check_in_id)
  end
end
