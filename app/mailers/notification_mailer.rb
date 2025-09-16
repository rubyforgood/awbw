class NotificationMailer < ApplicationMailer
  def reset_password_notification(resource)
    @resource = resource
    mail(
      to: "programs@awbw.org",
      subject: "Reset Password Request"
    )
  end
end
