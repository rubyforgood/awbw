class ContactUsMailer < ApplicationMailer
  default from: 'contactus@no-reply.com'

  def hello(contact_us)
    @contact_us = contact_us

    case @contact_us[:q]
    when "adult"
      @mail_to = "cturek@awbw.org"
    when "children"
      @mail_to = "cturekrials@awbw.org"
    when "general"
      @mail_to = "programs@awbw.org"
    else
      @mail_to = "programs@awbw.org"
    end

    mail(to: @mail_to, subject: @contact_us[:subject], from: @contact_us[:from])
  end
end
