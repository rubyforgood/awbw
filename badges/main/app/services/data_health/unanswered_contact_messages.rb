module DataHealth
  # Incoming messages (Contact us and replies) since launch that nobody has
  # marked responded — the same rows as the notifications index's
  # "Responded: No" filter.
  class UnansweredContactMessages < Check
    def title = "Contact us messages not marked responded"

    def explanation
      "Someone wrote in and nobody has marked it answered. Reply, or mark it responded if it was " \
      "handled another way."
    end

    def scope = unanswered.where(created_at: Notification::LAUNCHED_ON..).order(created_at: :desc)

    def aside
      Aside.new(
        count: unanswered.where(created_at: ...Notification::LAUNCHED_ON).count,
        text: "from the old system, #{before_launch_text}",
        path: notifications_path(responded_status: "no", to: (Notification::LAUNCHED_ON - 1).iso8601)
      )
    end

    def describe(notification)
      "#{notification.email_subject.presence || notification.kind.humanize} — " \
      "#{notification.recipient_email} (#{notification.created_at.to_date.to_fs(:long)})"
    end

    def path_for(notification) = notification_path(notification)

    def review_path = notifications_path(responded_status: "no", from: Notification::LAUNCHED_ON.iso8601)

    def review_label = "Unanswered messages"

    private

    def unanswered = Notification.responded_status("no")
  end
end
