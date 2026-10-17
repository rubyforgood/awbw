module DataHealth
  # Portal emails still pending past the delivery grace period — their send job
  # never finished — that nobody has resent yet. The notification page's Resend
  # button is the fix; a bulk resend would email people, so it stays by hand.
  class StuckNotifications < Check
    def title = "Emails stuck pending and not resent"

    def explanation
      "These never delivered and never failed, so the send most likely stalled. Nobody has resent " \
      "them yet. Open each one to check it's still worth sending, then resend it."
    end

    def scope
      resent_ids = Notification.where.not(parent_notification_id: nil).select(:parent_notification_id)

      Notification.pending.portal_sent
        .where(direction: "outgoing")
        .where(created_at: ...Notification::DELIVERY_GRACE_PERIOD.ago)
        .where.not(kind: Notification::DEVISE_KINDS)
        .where.not(id: resent_ids)
        .order(created_at: :desc)
    end

    def describe(notification)
      "#{notification.email_subject.presence || notification.kind.humanize} — " \
      "#{notification.recipient_email} (#{notification.created_at.to_date.to_fs(:long)})"
    end

    def path_for(notification) = notification_path(notification)

    def review_path = notifications_path(delivery_status: "pending")

    def review_label = "Pending emails"
  end
end
