# frozen_string_literal: true

class Admins::NotificationMailer < ApplicationMailer
  def email(notification)
    @notification = notification
    @noticeable   = notification.noticeable
    @type = "Report"
    target = if @noticeable.respond_to?(:windows_type)
      @noticeable.windows_type.name
    else
      ""
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
      @mail_to = case target
      when "ADULT WORKSHOP LOG"
        "cturek@awbw.org"
      else
        "rhernandez@awbw.org"
      end
    end

    mail(
      to: @mail_to,
      subject: "New #{@type} Submission by #{@user.name}",
    )
  end
end
