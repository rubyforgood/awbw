class ContactUsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :create ]
  rescue_from ActionController::InvalidAuthenticityToken do
    flash[:alert] = "Your session has expired. Please try submitting the form again."
    redirect_to contact_us_path
  end

  def index
    authorize! :contact_us, to: :index?
    @user = current_user if user_signed_in?
    @form_submitted = flash[:form_submitted] == true
  end

  def create
    authorize! :contact_us, to: :create?

    if params[:contact_us][:website_url].present?
      redirect_to contact_us_path
      return
    end

    user = current_user if user_signed_in?
    noticeable = user&.person || user

    # Send emails
    confirmation_mail = ContactUsMailer.confirmation(params[:contact_us], user).deliver_now
    admin_mail = ContactUsMailer.hello(params[:contact_us], user).deliver_now

    # Create notification for the submitter
    submitter_email = user&.email || params[:contact_us][:from]
    submitter_notification = NotificationServices::CreateNotification.call(
      noticeable: noticeable,
      recipient_role: :person,
      recipient_email: submitter_email,
      kind: "contact_us",
      notification_type: "contact_us_confirmation",
      deliver: false
    )
    NotificationServices::PersistDeliveredEmail.call(notification: submitter_notification, mail: confirmation_mail)

    # Create notification for admins
    admin_notification = NotificationServices::CreateNotification.call(
      noticeable: noticeable,
      recipient_role: :admin,
      recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      kind: "contact_us_fyi",
      notification_type: "contact_us_notification",
      deliver: false
    )
    NotificationServices::PersistDeliveredEmail.call(notification: admin_notification, mail: admin_mail)

    flash[:form_submitted] = true
    redirect_to contact_us_path(anchor: "thank-you")
  end

  private
end
