module DataHealth
  # Communications with a recipient address but no person. New notifications bind
  # to a person when they're created; these predate that.
  class UnboundNotifications < Check
    def title = "Communications not tied to a person"

    def explanation
      "These were sent before communications were linked to the person who received them, so they " \
      "don't appear in anyone's communications history. Matching on today's email could pick the " \
      "wrong person, so they're informational for now."
    end

    def scope
      Notification.where(person_id: nil).where.not(recipient_email: [ nil, "" ]).order(created_at: :desc)
    end

    def describe(notification)
      "#{notification.email_subject.presence || notification.kind} — " \
      "#{notification.recipient_email} (#{notification.created_at&.to_date&.to_fs(:long)})"
    end

    def path_for(notification) = notification_path(notification)
  end
end
