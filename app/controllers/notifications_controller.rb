class NotificationsController < ApplicationController
  before_action :set_notification, only: [ :show, :resend ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(Notification.includes(:noticeable))
    filtered = base_scope.search_by_params(params.to_unsafe_h)
    @notifications = filtered.order(created_at: :desc)
                             .paginate(page: params[:page], per_page: per_page)
  end

  def show
    authorize! @notification
  end

  def resend
    authorize! @notification, to: :resend?

    # Create a new notification for the resend
    new_notification = Notification.create!(
      noticeable: @notification.noticeable,
      kind: @notification.kind,
      recipient_email: @notification.recipient_email,
      recipient_role: @notification.recipient_role,
      notification_type: @notification.notification_type,
      resend: true
    )

    # Send the email using the appropriate mailer method
    mailer_method = @notification.kind.to_sym
    if NotificationMailer.respond_to?(mailer_method)
      mail = NotificationMailer.public_send(mailer_method, new_notification)
      mail.deliver_now

      # Update the new notification with email details
      new_notification.update!(
        email_subject: mail.subject,
        email_body_html: mail.html_part&.body&.decoded,
        email_body_text: mail.text_part&.body&.decoded || mail.body&.decoded,
        delivered_at: Time.current
      )
    end

    redirect_to @notification, notice: "Notification email has been resent successfully."
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end
end
