class NotificationMailer < ApplicationMailer
  def reset_password_notification(resource)
    @resource = resource
    message = mail(
      to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "Reset Password Request"
    )
    persist_email(notification, message)
    message
  end

  def created_notification(notification)
    @notification = notification
    @notification_type = notification.notification_type == 0 ? "created" : "updated"

    @noticeable   = notification.noticeable.decorate
    @noticeable_klass = @noticeable.object.class

    if @noticeable_klass == User
      @user        = @noticeable.object
    else
      @user        = @noticeable.try(:user) || @noticeable.try(:created_by)
    end

    primary_asset = @noticeable.primary_asset
    gallery_assets = @noticeable.gallery_assets
    @attachments = Asset.where(id: [ primary_asset&.id ] + gallery_assets.pluck(:id))
    @quotes      = @noticeable.quotes if @noticeable.respond_to?(:quotes)
    @answers     = @noticeable.report_form_field_answers if @noticeable.respond_to?(:report_form_field_answers)

    mail(
      to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "New #{@noticeable_klass} Submission by #{@user.name}"
    )
  end

  def submitted_notification(notification)
  end

  def report_notification(notification)
    @notification = notification
    @noticeable   = notification.noticeable
    @type = "Report"

    if @noticeable.class == User
      @user        = @noticeable
    else
      @report      = @noticeable
      @attachments = @report.assets
      @quotes      = @report.quotes if @report.respond_to?(:quotes)
      @user        = @noticeable.respond_to?(:user) ? @noticeable.user : @noticeable.respond_to?(:created_by) ? @noticeable.created_by : nil
      @answers     = @report.report_form_field_answers if @report.respond_to?(:report_form_field_answers)
    end

    mail(
      to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      subject: "New #{@type} Submission by #{@user.name}"
    )
  end

  def update_notification(notification, message)
    notification.update_columns(
      email_subject: message.subject,
      email_body_html: message.html_part&.body&.decoded,
      email_body_text: message.text_part&.body&.decoded
    )
  end
end
