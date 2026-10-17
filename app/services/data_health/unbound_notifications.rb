module DataHealth
  # Communications since launch with a recipient address that matched no person,
  # so they sit outside every communications history. Old-system rows are
  # counted aside — they predate person binding and won't be resolved.
  class UnboundNotifications < Check
    def title = "Communications not tied to a person"

    def explanation
      "Sent to an address that matched no one in the portal, so they don't appear in anyone's " \
      "communications history. Add the address to the right person, or create them."
    end

    def scope = unbound.where(created_at: Notification::LAUNCHED_ON..).order(created_at: :desc)

    def aside
      Aside.new(
        count: unbound.where(created_at: ...Notification::LAUNCHED_ON).count,
        text: "from the old system, #{before_launch_text}",
        path: notifications_path(to: (Notification::LAUNCHED_ON - 1).iso8601)
      )
    end

    def describe(notification)
      "#{notification.email_subject.presence || notification.kind} — " \
      "#{notification.recipient_email} (#{notification.created_at&.to_date&.to_fs(:long)})"
    end

    def path_for(notification) = notification_path(notification)

    private

    def unbound = Notification.where(person_id: nil).where.not(recipient_email: [ nil, "" ])
  end
end
