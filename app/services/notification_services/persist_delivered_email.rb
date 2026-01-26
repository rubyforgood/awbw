module NotificationServices
  class PersistDeliveredEmail
    def self.call(notification:, mail:)
      new(notification, mail).call
    end

    def initialize(notification, mail)
      @notification = notification
      @mail = mail
    end

    def call
      return if @notification.delivered_at.present?

      html, text = extract_bodies
      inline_attachments!(html)

      @notification.update!(
        email_subject: @mail.subject,
        email_body_html: html,
        email_body_text: text,
        delivered_at: Time.zone.now
      )
    end

    private

    def extract_bodies
      if @mail.multipart?
        [
          @mail.html_part&.body&.decoded,
          @mail.text_part&.body&.decoded
        ]
      else
        [ @mail.body.decoded, @mail.body.decoded ]
      end
    end

    def inline_attachments!(html)
      return unless html
      return unless @mail.attachments.any?

      @mail.attachments.each do |attachment|
        next unless attachment.content_id

        html.gsub!(
          "cid:#{attachment.content_id}",
          "data:#{attachment.mime_type};base64,#{Base64.strict_encode64(attachment.body.decoded)}"
        )
      end
    end
  end
end
