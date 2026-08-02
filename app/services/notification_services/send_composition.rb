module NotificationServices
  # Fans a saved composition out into notifications: one FYI parent (the batch
  # record that shows in the notifications table with a "N recipients" chevron)
  # plus one child per recipient. Children carry person_id and point back at the
  # FYI via batch_root_notification_id.
  #
  # Delivery is not wired yet: the records (and the batch/history) are created so
  # the fan-out mechanic is in place. The mailer that renders the styled AWBW
  # email — and enqueuing it — comes in the next slice.
  class SendComposition
    def self.call(composition, recipients:)
      new(composition, recipients).call
    end

    def initialize(composition, recipients)
      @composition = composition
      @recipients = recipients.select { |person| person.preferred_email.present? }
    end

    def call
      Notification.transaction do
        fyi = create_fyi
        @recipients.each { |person| create_delivery(person, fyi) }
        fyi
      end
    end

    private

    attr_reader :composition, :recipients

    def create_fyi
      Notification.create!(
        base_attributes.merge(
          kind: "bulk_email_fyi",
          recipient_role: "admin",
          recipient_email: composition.user.email,
          noticeable: composition.event
        )
      )
    end

    def create_delivery(person, fyi)
      Notification.create!(
        base_attributes.merge(
          kind: "bulk_email",
          recipient_role: "person",
          recipient_email: person.preferred_email,
          person_id: person.id,
          noticeable: person,
          batch_root_notification_id: fyi.id
        )
      )
    end

    def base_attributes
      {
        notification_type: 0,
        sender_id: composition.user_id,
        custom_subject: composition.subject,
        custom_message: composition.body
      }
    end
  end
end
