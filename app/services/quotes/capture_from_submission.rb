module Quotes
  # Materializes the answer to a "quote" smart field as a Quote when a submission
  # comes in — the smart field's whole job, mirroring how OtherResponses captures
  # "Other" answers. The quote carries no author, so it credits "Participant", and
  # records the submitter as its creator. It is linked back to the submission (a
  # quotable) so it shows its source and appears under the quotes Source filter.
  # The quote starts unpublished for an admin to review, refine, and publish.
  #
  # Idempotent per submission: re-running (an edited re-submission calls this
  # again) won't duplicate a quote already captured for the same answer text. The
  # match keys on the untouched `original_body`, so an admin editing the published
  # `body` doesn't cause a re-capture.
  #
  # Shared by the registration, scholarship, bulk-payment, and public-form
  # submission paths.
  class CaptureFromSubmission
    def self.call(submission)
      new(submission).call
    end

    def initialize(submission)
      @submission = submission
    end

    def call
      quote_answers.each { |answer| capture(answer) }
    end

    private

    def quote_answers
      @submission.form_answers.includes(:form_field).select do |answer|
        answer.form_field&.quote_field? && answer.submitted_answer.present?
      end
    end

    def capture(answer)
      return if @submission.quotes.exists?(original_body: answer.submitted_answer)

      quote = Quote.create!(body: answer.submitted_answer, created_by: @submission.person&.user)
      quote.quotable_item_quotes.create!(quotable: @submission)
    end
  end
end
