class ScholarshipMailer < ApplicationMailer
  default to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

  # Trainings-team heads-up when a recipient asks for more support instead of
  # accepting or declining — the award stays live, so staff can revisit the amount.
  def additional_support_requested_fyi(scholarship)
    assign_agreement(scholarship)
    mail(subject: fyi_subject("Additional scholarship support requested"))
  end

  # Trainings-team heads-up that a recipient declined their award (with reason).
  def declined_fyi(scholarship)
    assign_agreement(scholarship)
    mail(subject: fyi_subject("Scholarship declined"))
  end

  # Trainings-team heads-up that a recipient accepted their award.
  def accepted_fyi(scholarship)
    assign_agreement(scholarship)
    mail(subject: fyi_subject("Scholarship accepted"))
  end

  private

  def assign_agreement(scholarship)
    @scholarship = scholarship.decorate
    @recipient = scholarship.recipient
    @event = scholarship.event&.decorate
    @response = scholarship.latest_agreement_response
  end

  def fyi_subject(action)
    "AWBW Portal: [FYI] #{action} by #{@recipient&.full_name}"
  end
end
