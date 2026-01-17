class NotificationMailer < ApplicationMailer
  helper Rails.application.routes.url_helpers

  def reset_password_fyi(notification)
    @user = notification.noticeable
    @facilitator = @user.facilitator
    @notification_type = "Password reset"

    # Send email to the admin
    mail(
      to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "AWBW portal: user password reset for #{@user.email}"
    )
  end

  def idea_submitted_fyi(notification)
    @notification = notification
    @notification_type = notification.notification_type == 0 ? "created" : "updated"

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
      to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "New #{@noticeable_klass} Submission by #{@user.name}"
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
      to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "New #{@type} Submission by #{@user.name}"
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
