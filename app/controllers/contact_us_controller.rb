class ContactUsController < ApplicationController
  rescue_from(*EmailDeliveryErrorHandler::ERRORS) { |e| EmailDeliveryErrorHandler.handle(e, self) }

  skip_before_action :authenticate_user!, only: [ :index, :create ]

  # Subject presets offered on the Story Share portal variant; picking one fills
  # the subject line so submissions route to the right team.
  PORTAL_SUBJECT_OPTIONS = [
    "General inquiry",
    "Interest in starting a healing arts program",
    "Interest in Windows Facilitator trainings",
    "Interest in hiring AWBW to lead an art workshop",
    "Current or former Windows Facilitator"
  ].freeze

  def index
    authorize! :contact_us, to: :index?
    @user = current_user if user_signed_in?
    @form_submitted = flash[:form_submitted] == true
    @from_story_share = params[:from] == "story_share"
    @prefilled_subject = params[:subject]
    @prefilled_message = params[:message]
    @return_to = params[:return_to]
    render layout: "story_shares" if @from_story_share
  end

  def create
    authorize! :contact_us, to: :create?
    from = "story_share" if params[:from] == "story_share"
    return_to = params[:return_to].presence

    if Honeypot.tripped?(params, :contact_us)
      redirect_to contact_us_path(from: from, return_to: return_to)
      return
    end

    user = current_user if user_signed_in?
    noticeable = user&.person || user
    contact_us = contact_us_params

    # Deliver in the background so a slow/hung SMTP server can't time out the request.
    confirmation_mail = ContactUsMailer.confirmation(contact_us, user)
    admin_mail = ContactUsMailer.hello(contact_us, user)
    confirmation_mail.deliver_later
    admin_mail.deliver_later

    # Create notification for the submitter
    submitter_email = user&.email || contact_us[:from]
    submitter_notification = NotificationServices::CreateNotification.call(
      noticeable: noticeable,
      recipient_role: :person,
      recipient_email: submitter_email,
      kind: "contact_us",
      notification_type: "contact_us_confirmation",
      deliver: false
    )
    NotificationServices::PersistDeliveredEmail.call(notification: submitter_notification, mail: confirmation_mail.message)

    # Create notification for admins
    admin_notification = NotificationServices::CreateNotification.call(
      noticeable: noticeable,
      recipient_role: :admin,
      recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      kind: "contact_us_fyi",
      notification_type: "contact_us_notification",
      deliver: false
    )
    NotificationServices::PersistDeliveredEmail.call(notification: admin_notification, mail: admin_mail.message)

    flash[:form_submitted] = true
    redirect_to contact_us_path(anchor: "thank-you", from: from, return_to: return_to)
  end

  private

  # A plain symbol-keyed hash so the mailer args serialize for the background job.
  def contact_us_params
    params.require(:contact_us)
          .permit(:first_name, :last_name, :from, :organization, :subject, :message, :q)
          .to_h
          .symbolize_keys
  end
end
