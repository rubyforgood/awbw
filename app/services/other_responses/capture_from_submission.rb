module OtherResponses
  # Materializes the free-text "Other" answers on a form submission as
  # OtherResponse records so they can be curated (promoted/kept/dismissed).
  #
  # Runs over every answered field — not just sectors — because any question can
  # offer an "Other" option. OtherOption.texts keys strictly on the "Other:"
  # prefix, so named specify options ("Word of Mouth: …") and the CE "Yes: 3"
  # box are ignored. De-dupes on the person's normalized value per question, so
  # re-submitting the same answer never creates a second row.
  #
  # Shared by the registration, scholarship, and bulk-payment submission paths.
  class CaptureFromSubmission
    # Fields whose "Other" belongs to the organization, not the person, so they
    # must not land in the person's review queue. Organization type is synced
    # onto the org (PublicRegistration#sync_agency_type) and will get its own
    # promotable path when OrganizationType becomes a model.
    EXCLUDED_FIELD_IDENTIFIERS = %w[agency_type].freeze

    def self.call(submission)
      new(submission).call
    end

    def initialize(submission)
      @submission = submission
    end

    def call
      answers.each do |answer|
        field_identifier = answer.form_field&.field_identifier
        next if field_identifier.blank? || field_identifier.in?(EXCLUDED_FIELD_IDENTIFIERS)

        OtherOption.texts(answer.submitted_answer).each do |text|
          capture(field_identifier, text, answer)
        end
      end
    end

    private

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
