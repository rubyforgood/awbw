require "rails_helper"

RSpec.describe OtherResponses::CaptureFromSubmission do
  let(:person) { create(:person) }
  let(:form) { create(:form) }
  let(:submission) { create(:form_submission, person: person, form: form) }

  def answer(identifier, value)
    field = create(:form_field, form: form, field_identifier: identifier)
    create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
  end

  it "captures Other answers from any question, tagged with the field and kind" do
    answer("additional_sectors", "5, Other: Equine therapy")
    answer("how_did_you_hear", "Other: A friend")

    described_class.call(submission)

    responses = person.other_responses.order(:field_identifier)
    expect(responses.map { |r| [ r.field_identifier, r.text, r.kind ] }).to contain_exactly(
      [ "additional_sectors", "Equine therapy", "sector" ],
      [ "how_did_you_hear", "A friend", "generic" ]
    )
  end

  it "ignores answers with no Other free text and named specify options" do
    answer("additional_sectors", "5, 12")
    answer("how_did_you_hear", "Word of Mouth: Jane")

    described_class.call(submission)

    expect(person.other_responses).to be_empty
  end

  it "does not capture the organization-owned agency_type Other" do
    answer("agency_type", "Other: Nonprofit collective")

    described_class.call(submission)

    expect(person.other_responses).to be_empty
  end

  it "de-dupes repeat submissions of the same value per question" do
    answer("additional_sectors", "Other: Equine therapy")
    described_class.call(submission)
    described_class.call(submission)

    expect(person.other_responses.count).to eq(1)
  end

  it "records the source form answer for provenance" do
    source = answer("additional_sectors", "Other: Equine therapy")
    described_class.call(submission)

    expect(person.other_responses.first.source_form_answer).to eq(source)
  end
end
