class ContactUsMailer < ApplicationMailer
  default from: "contactus@no-reply.com"

  def hello(contact_us)
    @contact_us = contact_us

    @mail_to = ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

    mail(to: @mail_to, subject: @contact_us[:subject], from: @contact_us[:from])
  end
end
