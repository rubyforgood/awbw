module Quotes
  # Materializes a submission's quote smart fields as a Quote — the fields' whole
  # job, mirroring how OtherResponses captures "Other" answers. The quote text
  # comes from the "quote" (or "quote_body") answer; "quote_speaker_name" and
  # "quote_age_range" flesh out the speaker and age when the form collects them.
  # With no speaker the quote credits "Anonymous"; the submitter is recorded as
  # its creator, and the submission is kept as the quote's source. The quote
  # starts unpublished for an admin to review, refine, and publish.
  #
  # Idempotent per submission: re-running (an edited re-submission calls this
  # again) won't duplicate a quote already captured for the same text. The match
  # keys on the untouched `original_body`, so an admin editing the published
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
      body = quote_body
      return if body.blank?
      return if @submission.quotes.exists?(original_body: body)

      quote = Quote.create!(
        body: body,
        speaker_name: answers[FormField::QUOTE_SPEAKER_NAME_FIELD_IDENTIFIER].presence,
        age: answers[FormField::QUOTE_AGE_RANGE_FIELD_IDENTIFIER].presence,
        created_by: @submission.person&.user
      )
      quote.quotable_item_quotes.create!(quotable: @submission)
    end

    private

    def answers
      @answers ||= @submission.answers_by_identifier
    end

    def quote_body
      FormField::QUOTE_BODY_FIELD_IDENTIFIERS.filter_map { |id| answers[id].presence }.first
    end
  end
end
