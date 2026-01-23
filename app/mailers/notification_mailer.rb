class NotificationMailer < ApplicationMailer
  default to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

  def event_registration_confirmation_fyi(notification)
    @event_registration = notification.noticeable
    @event = @event_registration.event.decorate
    @user = @event_registration.registrant
    @facilitator = @user.facilitator
    @notification_type = "Event registration"

    # Send email to the admin
    mail(
      subject: "AWBW portal: new event registration by #{@user.full_name} to #{@event.title}"
    )
  end


  def idea_submitted_fyi(notification)
    @notification = notification

    @noticeable   = notification.noticeable.decorate
    @noticeable_klass = @noticeable.object.class

    if @noticeable_klass == User
      @user        = @noticeable.object
    else
      @user        = @noticeable.try(:user) || @noticeable.try(:created_by)
    end

    @attachments = extract_attachments(@noticeable)
    @quotes      = @noticeable.quotes if @noticeable.respond_to?(:quotes)
    @answers     = @noticeable.report_form_field_answers if @noticeable.respond_to?(:report_form_field_answers)

    mail(
      subject: "AWBW portal: new #{@noticeable_klass} submission by #{@user.full_name}"
    )
  end

  def report_submitted_fyi(notification)
    @notification = notification
    @noticeable   = notification.noticeable
    @type = "Report"

    if @noticeable.class == User
      @user        = @noticeable
    else
      @report      = @noticeable
      @attachments = extract_attachments(@noticeable)
      @quotes      = @report.quotes if @report.respond_to?(:quotes)
      @user        = @noticeable.respond_to?(:user) ? @noticeable.user : @noticeable.respond_to?(:created_by) ? @noticeable.created_by : nil
      @answers     = @report.report_form_field_answers if @report.respond_to?(:report_form_field_answers)
    end

    mail(
      subject: "AWBW portal: new #{@type} submission by #{@user.full_name}"
    )
  end

  def reset_password_fyi(notification)
    @user = notification.noticeable
    @facilitator = @user.facilitator
    @notification_type = "Password reset"

    # Send email to the admin
    mail(
      subject: "AWBW portal: user password reset by #{@user.full_name}"
    )
  end

  def workshop_log_submitted_fyi(notification)
    @notification = notification
    @noticeable   = notification.noticeable
    @type = "WorkshopLog"

    if @noticeable.class == User
      @user        = @noticeable
    else
      @report      = @noticeable
      @attachments = extract_attachments(@noticeable)
      @quotes      = @report.quotes if @report.respond_to?(:quotes)
      @user        = @noticeable.respond_to?(:user) ? @noticeable.user : @noticeable.respond_to?(:created_by) ? @noticeable.created_by : nil
      @answers     = @report.report_form_field_answers if @report.respond_to?(:report_form_field_answers)
    end

    mail(
      subject: "AWBW portal: new WorkshopLog submission by #{@user.full_name}"
    )
  end

  private

  def extract_attachments(noticeable)
    return [] unless noticeable.respond_to?(:primary_asset)

    assets = []
    assets << noticeable.primary_asset if noticeable.primary_asset
    assets.concat(noticeable.gallery_assets) if noticeable.respond_to?(:gallery_assets)
    assets
  end
end
