# Alerts Honeybadger when portal emails stall: pending past the grace period without failing.
# A day's lookback keeps one old unsent email from alerting forever.
class StuckEmailsAlertJob < ApplicationJob
  queue_as :default

  LOOKBACK = 1.day

  def perform
    count = DataHealth::StuckNotifications.new.scope.where(created_at: LOOKBACK.ago..).count
    return if count.zero?

    Honeybadger.notify("#{count} portal #{"email".pluralize(count)} stuck pending",
                       error_class: "StuckEmails", fingerprint: "stuck_emails", context: { count: count })
  end
end
