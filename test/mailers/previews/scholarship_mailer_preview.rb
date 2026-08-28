class ScholarshipMailerPreview < ActionMailer::Preview
  def additional_support_requested_fyi
    scholarship = Scholarship.joins(:agreement_responses)
      .where(agreement_response_status: "support_requested").first ||
      Scholarship.first ||
      raise("Need a Scholarship")

    unless scholarship.agreement_support_requested?
      scholarship.request_additional_support!(contribution_cents: 15_000, reason: "My employer can cover part of the fee.")
    end

    ScholarshipMailer.additional_support_requested_fyi(scholarship)
  end
end
