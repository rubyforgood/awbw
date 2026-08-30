class ScholarshipMailerPreview < ActionMailer::Preview
  def additional_support_requested_fyi
    scholarship = a_scholarship
    unless scholarship.agreement_support_requested?
      scholarship.request_additional_support!(contribution_cents: 15_000, reason: "My employer can cover part of the fee.")
    end

    ScholarshipMailer.additional_support_requested_fyi(scholarship)
  end

  def declined_fyi
    scholarship = a_scholarship
    scholarship.decline_agreement!("The timing no longer works for me.") unless scholarship.agreement_declined?

    ScholarshipMailer.declined_fyi(scholarship)
  end

  def accepted_fyi
    scholarship = a_scholarship
    scholarship.accept_agreement! unless scholarship.agreement_signed?

    ScholarshipMailer.accepted_fyi(scholarship)
  end

  def accepted_confirmation
    scholarship = a_scholarship
    scholarship.accept_agreement! unless scholarship.agreement_signed?

    ScholarshipMailer.accepted_confirmation(scholarship)
  end

  private

  def a_scholarship
    Scholarship.first || raise("Need a Scholarship")
  end
end
