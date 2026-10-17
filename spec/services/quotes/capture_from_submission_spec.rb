require "rails_helper"

RSpec.describe Quotes::CaptureFromSubmission do
  let(:submitter) { create(:user, :with_person) }
  let(:form) { create(:form) }
  let(:submission) { create(:form_submission, person: submitter.person, form: form) }

  def answer(identifier, value, name: identifier.humanize)
    field = create(:form_field, form: form, field_identifier: identifier, name: name)
    create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
  end

  def field_for(identifier)
    form.form_fields.find_by(field_identifier: identifier)
  end

  it "saves a quote-field answer as an unpublished quote sourced from the submission" do
    answer("quote", "Painting gave me a voice")

    expect { described_class.call(submission) }.to change(Quote, :count).by(1)

    quote = submission.quotes.sole
    expect(quote.body).to eq("Painting gave me a voice")
    expect(quote).not_to be_published
    expect(quote.author).to be_nil
    expect(quote.author_credit).to eq("Anonymous")
    expect(quote.created_by).to eq(submitter)
  end

  it "populates the speaker name and age when those fields are present" do
    answer("quote_body", "The colors held everything I couldn't say")
    answer("quote_speaker_name", "Jordan")
    answer("quote_age_range", "13-17")

    described_class.call(submission)

    quote = submission.quotes.sole
    expect(quote.body).to eq("The colors held everything I couldn't say")
    expect(quote.speaker_name).to eq("Jordan")
    expect(quote.age).to eq("13-17")
    expect(quote.author_credit).to eq("Jordan")
  end

  it "prefers quote_body over the simple quote field for the text" do
    answer("quote", "simple text")
    answer("quote_body", "structured text")

    described_class.call(submission)

    expect(submission.quotes.sole.body).to eq("structured text")
  end

  it "credits Anonymous when no speaker name is given" do
    answer("quote", "A quiet, powerful line")

    described_class.call(submission)

    expect(submission.quotes.sole.author_credit).to eq("Anonymous")
  end

  it "credits no creator when the submitter has no account" do
    accountless = create(:person, user: nil)
    submission.update!(person: accountless)
    answer("quote", "A quiet, powerful line")

    described_class.call(submission)

    expect(submission.quotes.sole.created_by).to be_nil
  end

  it "ignores questions without a quote identifier" do
    answer("first_name", "Priya", name: "First name")

    expect { described_class.call(submission) }.not_to change(Quote, :count)
  end

  it "does nothing when only speaker/age are answered but there is no quote text" do
    answer("quote_speaker_name", "Jordan")
    answer("quote_age_range", "13-17")

    expect { described_class.call(submission) }.not_to change(Quote, :count)
  end

  it "ignores a blank quote answer" do
    answer("quote", "")

    expect { described_class.call(submission) }.not_to change(Quote, :count)
  end

  it "does not duplicate a quote when the submission is captured again" do
    answer("quote", "Only once, please")
    described_class.call(submission)

    expect { described_class.call(submission) }.not_to change(Quote, :count)
  end

  it "rewrites the quote it captured when the answer is edited" do
    answer("quote", "First try")
    described_class.call(submission)
    submission.form_answers.sole.update!(submitted_answer: "Second try, typo fixed")

    expect { described_class.call(submission) }.not_to change(Quote, :count)
    expect(submission.quotes.reload.sole)
      .to have_attributes(body: "Second try, typo fixed", original_body: "Second try, typo fixed")
  end

  it "refreshes the speaker and age alongside a rewritten body" do
    answer("quote", "First try")
    speaker = answer("quote_speaker_name", "Jordn")
    described_class.call(submission)
    submission.form_answers.find_by(form_field: field_for("quote")).update!(submitted_answer: "Second try")
    speaker.update!(submitted_answer: "Jordan")

    described_class.call(submission)

    expect(submission.quotes.reload.sole).to have_attributes(body: "Second try", speaker_name: "Jordan")
  end

  it "keeps an admin's rewording and records the edited answer as the original" do
    answer("quote", "First try")
    described_class.call(submission)
    submission.quotes.sole.update!(body: "A refined version")
    submission.form_answers.sole.update!(submitted_answer: "Second try")

    expect { described_class.call(submission) }.not_to change(Quote, :count)
    expect(submission.quotes.reload.sole)
      .to have_attributes(body: "A refined version", original_body: "Second try")
  end

  it "rewrites a published quote rather than adding a second one" do
    answer("quote", "First try")
    described_class.call(submission)
    submission.quotes.sole.update!(published: true)
    submission.form_answers.sole.update!(submitted_answer: "Second try")

    expect { described_class.call(submission) }.not_to change(Quote, :count)
    expect(submission.quotes.reload.sole).to have_attributes(body: "Second try", published: true)
  end

  it "still recognizes the answer after an admin edited the published body" do
    answer("quote", "The untouched original")
    described_class.call(submission)
    submission.quotes.sole.update!(body: "An edited, published version")

    expect { described_class.call(submission) }.not_to change(Quote, :count)
  end
end
