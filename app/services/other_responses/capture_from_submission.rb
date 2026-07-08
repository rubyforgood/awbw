module OtherResponses
  # Materializes the free-text "Other" answers on a form submission as
  # OtherResponse records so they can be curated (promoted/kept/dismissed).
  #
  # Only questions whose "Other" can eventually become a real tag are captured
  # (sectors today; organization type once OrganizationType is a model). Every
  # other "Other" — and the org-owned agency_type — is left in the form answers,
  # which stay searchable, rather than stored here. The record still carries
  # `field_identifier`, so flipping a new question on later is a one-line change
  # (add it to a promotable kind). OtherOption.texts keys strictly on the
  # "Other:" prefix, so named specify options ("Word of Mouth: …") and the CE
  # "Yes: 3" box are ignored. De-dupes per person + question.
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

    # Capture only the questions whose "Other" is (or will be) promotable — the
    # rest stay searchable in the form answers.
    def capturable?(field_identifier)
      field_identifier.present? &&
        OtherResponse.kind_for(field_identifier).in?(OtherResponse::PROMOTABLE_KINDS)
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
