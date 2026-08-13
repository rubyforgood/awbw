class ContactUsMailer < ApplicationMailer
  def hello(contact_us, user = nil)
    @contact_us = contact_us
    @user = user

    # When the message came from a scholarship page, link the team to that
    # registration (threaded through as a slug on the form).
    @registration = EventRegistration.find_by(slug: contact_us[:registration_id]) if contact_us[:registration_id].present?

    @mail_to = ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

    sender_name = if user.present?
      user.full_name
    else
      "#{contact_us[:first_name]} #{contact_us[:last_name]}".strip
    end

    mail(to: @mail_to, subject: "AWBW Portal: [FYI] New contact form submission from #{sender_name}: #{@contact_us[:subject]}", from: @contact_us[:from])
  end

  def confirmation(contact_us, user = nil)
    @contact_us = contact_us
    @user = user

    recipient = user&.email || contact_us[:from]
    mail(to: recipient, subject: "AWBW Portal: We received your message re #{contact_us[:subject]}")
  end
end
