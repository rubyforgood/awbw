class ScholarshipMailer < ApplicationMailer
  default to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

  # Trainings-team heads-up that a recipient asked for more support instead of
  # accepting or declining — deliberately distinct from a decline (the award is
  # still live) so staff can revisit the amount. Reads the recipient's contribution
  # and note off the latest agreement response.
  def additional_support_requested_fyi(scholarship)
    @scholarship = scholarship.decorate
    @recipient = scholarship.recipient
    @event = scholarship.event&.decorate
    @response = scholarship.latest_agreement_response

    mail(
      subject: "AWBW Portal: [FYI] Additional scholarship support requested by #{@recipient&.full_name}"
    )
  end
end
