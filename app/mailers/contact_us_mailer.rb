# frozen_string_literal: true

class ContactUsMailer < ApplicationMailer
  default from: "contactus@no-reply.com"

  def hello(contact_us)
    @contact_us = contact_us

    @mail_to = case @contact_us[:q]
    when "adult"
      "cturek@awbw.org"
    when "children"
      "cturekrials@awbw.org"
    when "general"
      "programs@awbw.org"
    else
      "programs@awbw.org"
    end

    mail(to: @mail_to, subject: @contact_us[:subject], from: @contact_us[:from])
  end
end
