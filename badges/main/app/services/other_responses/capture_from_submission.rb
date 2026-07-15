module OtherResponses
  # Materializes the free-text "Other" answers on a form submission as
  # OtherResponse records so they can be curated (promoted/kept/dismissed).
  #
  # Captures the person-owned "Other" answers (sectors today). Organization-type
  # "Other" is owned by the org and captured separately, where the org is known
  # (PublicRegistration#sync_agency_type). Questions whose "Other" will never
  # become a tag are left in the form answers, which stay searchable, rather than
  # stored here — but the record still carries `field_identifier`, so switching a
  # new question on later is a one-line change. OtherOption.texts keys strictly
  # on the "Other:" prefix, so named specify options ("Word of Mouth: …") and the
  # CE "Yes: 3" box are ignored. De-dupes per person + question.
  #
  # Shared by the registration, scholarship, and bulk-payment submission paths.
  class CaptureFromSubmission
    def self.call(submission)
      new(submission).call
    end

    def initialize(submission)
      @submission = submission
    end

    def call
      answers.each do |answer|
        field_identifier = answer.form_field&.field_identifier
        next unless capturable?(field_identifier)

        OtherOption.texts(answer.submitted_answer).each do |text|
          capture(field_identifier, text, answer)
        end
      end
    end

    private

    # Capture only the person-owned "Other" questions here — the rest stay
    # searchable in the form answers (or, for org-type, are captured elsewhere).
    def capturable?(field_identifier)
      field_identifier.present? &&
        OtherResponse.kind_for(field_identifier).in?(OtherResponse::PERSON_KINDS)
    end

    def answers
      @submission.form_answers.includes(:form_field)
    end

    def capture(field_identifier, text, answer)
      @submission.person.other_responses.find_or_create_by!(
        field_identifier: field_identifier,
        normalized_text: OtherResponse.normalize(text)
      ) do |response|
        response.text = text
        response.source_form_answer = answer
      end
    end
  end
end
