class NotificationMailer < ApplicationMailer
  def reset_password_notification(resource)
    @resource = resource
    mail(
      to: "programs@awbw.org",
      subject: "Reset Password Request"
    )
  end

  def report_notification(notification)
    @notification = notification
    @noticeable   = notification.noticeable
    @type = 'Report'
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
      @type = 'Story'
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
end
