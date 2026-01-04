class NotificationMailer < ApplicationMailer
  def reset_password_notification(resource)
    @resource = resource
    message = mail(
      to: "programs@awbw.org",
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

    if @noticeable_klass == WorkshopLog
    end

    mail(
      to: ENV.fetch("REPLY_EMAIL", "programs@awbw.org"),
      subject: "New #{@noticeable_klass} Submission by #{@user.name}"
    )
  end

  def submitted_notification(notification)
  end

  def report_notification(notification)
    @notification = notification
    @noticeable   = notification.noticeable
    @type = "Report"
    if @noticeable.respond_to? :windows_type
      target = @noticeable.windows_type.name
    else
      target = ""
    end

    if @noticeable.class == User
      @user        = @noticeable
    else
      @report      = @noticeable
      @attachments = @report.media_files
      @quotes      = @report.quotes
      @user        = @noticeable.user
      @answers     = @report.report_form_field_answers
    end

    if @report.type == "WorkshopLog"
    end

    if @report.story?
      @type = "Story"
      @mail_to = "eaeevans@awbw.org, cturekrials@awbw.org, rhernandez@awbw.org"
    else
      case target
      when "ADULT WORKSHOP LOG"
        @mail_to = "cturek@awbw.org"
      else
        @mail_to = "rhernandez@awbw.org"
      end
    end

    mail(
      to: @mail_to,
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
