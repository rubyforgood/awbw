class ContactUsMailer < ApplicationMailer
  def hello(contact_us, user = nil)
    @contact_us = contact_us
    @user = user

    @mail_to = ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

    sender_name = if user.present?
      user.full_name
    else
      "#{contact_us[:first_name]} #{contact_us[:last_name]}".strip
    end

    mail(to: @mail_to, subject: "AWBW portal: New contact form submission from #{sender_name}: #{@contact_us[:subject]}", from: @contact_us[:from])
  end

  def confirmation(contact_us, user = nil)
    @contact_us = contact_us
    @user = user

    recipient = user&.email || contact_us[:from]
    mail(to: recipient, subject: "AWBW portal: We received your message re #{contact_us[:subject]}")
  end
end
