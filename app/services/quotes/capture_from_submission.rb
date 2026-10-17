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
  # `body` doesn't cause a re-capture. A re-submission that changes the text
  # rewrites the quote it captured, so only the current answer sits in the
  # review queue — unless an admin has published or reworded that quote, which
  # makes it theirs to keep and the new text its own capture.
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

      captured = quote_as_captured
      return captured.update!(body: body, original_body: body, speaker_name: speaker_name, age: age) if captured

      quote = Quote.create!(
        body: body,
        speaker_name: speaker_name,
        age: age,
        created_by: @submission.person&.user
      )
      quote.quotable_item_quotes.create!(quotable: @submission)
    end

    private

    # The submission's quote while it still reads exactly as captured. A reworded
    # or published one is the admin's, so it's left out and the edited answer is
    # captured as its own quote.
    def quote_as_captured
      @submission.quotes.where(published: false).detect { |quote| quote.body == quote.original_body }
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
