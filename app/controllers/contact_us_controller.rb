class ContactUsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :create ]

  def index
    authorize! :contact_us, to: :index?
    @user = current_user if user_signed_in?
    @form_submitted = params[:submitted] == "true"
  end

  def create
    authorize! :contact_us, to: :create?
    user = current_user if user_signed_in?
    ContactUsMailer.hello(params[:contact_us], user).deliver_now

    # Create notification for the submitter
    submitter_email = user&.email || params[:contact_us][:from]
    Notification.create!(
      kind: "contact_us",
      recipient_role: :person,
      recipient_email: submitter_email,
      email_subject: "Contact form submission received",
      notification_type: "contact_us_confirmation",
      noticeable: user
    )

    # Create notification for admins
    Notification.create!(
      kind: "contact_us_fyi",
      recipient_role: :admin,
      recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      email_subject: params[:contact_us][:subject],
      notification_type: "contact_us_notification",
      noticeable: user
    )

    redirect_to contact_us_path(submitted: true)
  end

  private

  def create_notification(kind:, recipient_role:, recipient_email:, email_subject:, notification_type:, noticeable:)
    Notification.create!(
      kind: kind,
      recipient_role: recipient_role,
      recipient_email: recipient_email,
      email_subject: email_subject,
      notification_type: notification_type,
      noticeable: noticeable
    )
  end
end
