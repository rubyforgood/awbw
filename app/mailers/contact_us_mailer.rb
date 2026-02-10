class ContactUsMailer < ApplicationMailer
  def hello(contact_us, user = nil)
    @contact_us = contact_us
    @user = user

    @mail_to = ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

    mail(to: @mail_to, subject: @contact_us[:subject], from: @contact_us[:from])
  end
end
