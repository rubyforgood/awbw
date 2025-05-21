class NotificationMailer < ApplicationMailer
  require "mandrill"
  
  def reset_password_notification(resource)
    @resource = resource
    mail(
      to: "programs@awbw.org",
      subject: "Reset Password Request"
    )
  end
end
