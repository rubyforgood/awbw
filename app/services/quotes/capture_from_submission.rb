module Quotes
  # Materializes a submission's quote smart fields as a Quote — the fields' whole
  # job, mirroring how OtherResponses captures "Other" answers. The quote text
  # comes from the "quote" (or "quote_body") answer; "quote_speaker_name" and
  # "quote_age_range" flesh out the speaker and age when the form collects them.
  # With no speaker the quote credits "Anonymous"; the submitter is recorded as
  # its creator, and the submission is kept as the quote's source. The quote
  # starts unpublished for an admin to review, refine, and publish.
  #
  # One quote per submission: re-running (an edited re-submission calls this
  # again) rewrites the quote it already captured rather than adding a second one,
  # so the review queue never holds a superseded version beside the current text.
  #
  # Shared by the registration, scholarship, bulk-payment, ticket-callout, and
  # public-form submission paths.
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

      captured = @submission.quotes.order(:id).last
      return rewrite(captured, body) if captured

      quote = Quote.create!(
        body: body,
        speaker_name: speaker_name,
        age: age,
        created_by: @submission.person&.user
      )
      quote.quotable_item_quotes.create!(quotable: @submission)
    end

    private

    # `original_body` always catches up to what the person now says. The displayed
    # `body` follows only while it still reads as captured, so an admin's rewording
    # survives their source fixing a typo.
    def rewrite(quote, body)
      return quote.update!(original_body: body) unless quote.body == quote.original_body

      quote.update!(body: body, original_body: body, speaker_name: speaker_name, age: age)
    end

    def answers
      @answers ||= @submission.answers_by_identifier
    end

    def quote_body
      FormField::QUOTE_BODY_FIELD_IDENTIFIERS.filter_map { |id| answers[id].presence }.first
    end

    def speaker_name
      answers[FormField::QUOTE_SPEAKER_NAME_FIELD_IDENTIFIER].presence
    end

    def age
      answers[FormField::QUOTE_AGE_RANGE_FIELD_IDENTIFIER].presence
    end
  end
end
