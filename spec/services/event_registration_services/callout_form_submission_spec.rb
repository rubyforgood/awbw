require "rails_helper"

RSpec.describe EventRegistrationServices::CalloutFormSubmission do
  let(:event) { create(:event) }
  let(:registration) { create(:event_registration, event:) }
  let(:form) { create(:form) }
  let!(:field) { create(:form_field, form:, name: "How was it?") }
  let(:callout) { create(:registration_ticket_callout, event:, form:) }

  # The service returns itself; the persisted submission hangs off #submission.
  def submit(params, clarity: {}, on: form)
    described_class.call(registration:, callout:, form: on, form_params: params.merge(clarity)).submission
  end

  it "records the answers under the form's own role (nil for a role-less form)" do
    submission = submit({ field.id.to_s => "Great" })

    expect(submission).to have_attributes(
      person: registration.registrant, form:, event:, role: nil
    )
    expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Great")
  end

  it "attributes the request's changes to the callout submission" do
    submission = submit({ field.id.to_s => "Great" })

    expect(Current.form_submission_id).to eq(submission.id)
  end

  it "carries the form's own role when it has one" do
    form.update!(role: "registration")

    expect(submit({ field.id.to_s => "Great" }).role).to eq("registration")
  end

  it "records in metadata that the submission was collected via a callout" do
    submission = submit({ field.id.to_s => "Great" })

    expect(submission.collected_via_callout?).to be(true)
    expect(submission.metadata["collected_via_callout_id"]).to eq(callout.id)
  end

  it "edits the existing submission in place on re-submit" do
    submit({ field.id.to_s => "Great" })

    expect {
      submission = submit({ field.id.to_s => "Even better" })
      expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Even better")
    }.not_to change(FormSubmission, :count)
  end

  it "edits the existing submission in place after the form's role changes" do
    form.update!(role: "day_1_survey")
    original = submit({ field.id.to_s => "Great" })
    form.update!(role: "general")

    expect {
      expect(submit({ field.id.to_s => "Even better" })).to eq(original)
    }.not_to change(FormSubmission, :count)
  end

  it "reports edited? — false on a first submission, true on a re-submit" do
    first = described_class.call(registration:, callout:, form:, form_params: { field.id.to_s => "Great" })
    expect(first.edited?).to be(false)

    again = described_class.call(registration:, callout:, form:, form_params: { field.id.to_s => "Even better" })
    expect(again.edited?).to be(true)
  end

  it "captures a sector 'Other' answer for the review queue, linked to its answer" do
    sector_field = create(:form_field, form:, field_identifier: "additional_sectors")

    submission = submit({ sector_field.id.to_s => "Other: Equine therapy" })

    response = registration.registrant.other_responses.sole
    expect([ response.text, response.source_form_answer ])
      .to eq([ "Equine therapy", submission.form_answers.find_by(form_field: sector_field) ])
  end

  it "captures a quote answer as an unpublished quote sourced to the submission" do
    quote_field = create(:form_field, form:, field_identifier: FormField::QUOTE_FIELD_IDENTIFIER)

    submission = submit({ quote_field.id.to_s => "Art helped me heal." })

    expect(submission.quotes.pluck(:original_body)).to eq([ "Art helped me heal." ])
  end

  it "does not duplicate a captured quote on re-submit" do
    quote_field = create(:form_field, form:, field_identifier: FormField::QUOTE_FIELD_IDENTIFIER)
    submit({ quote_field.id.to_s => "Art helped me heal." })

    expect { submit({ quote_field.id.to_s => "Art helped me heal." }) }.not_to change(Quote, :count)
  end

  it "rewrites the captured quote when the registrant edits their answer" do
    quote_field = create(:form_field, form:, field_identifier: FormField::QUOTE_FIELD_IDENTIFIER)
    submit({ quote_field.id.to_s => "Art helped me heel." })

    submission = submit({ quote_field.id.to_s => "Art helped me heal." })

    expect(submission.quotes.pluck(:body)).to eq([ "Art helped me heal." ])
  end

  describe "a survey-role form's side effects" do
    let(:form) { create(:form, role: "recipient_survey") }
    let!(:clarity_field) do
      create(:form_field, form:, answer_type: :single_select_radio,
        name: "Overall, was the information presented in a clear and concise manner for")
    end
    let(:triple_focus) { create(:resource, title: "Triple Focus") }
    let(:listening) { create(:resource, title: "Listening is Art") }
    let!(:anon_field) do
      create(:form_field, form:, answer_type: :single_select_radio, name: "Anonymity?",
        field_identifier: "anonymous_contributions")
    end
    let!(:name_field) do
      create(:form_field, form:, answer_type: :single_select_radio, name: "Name?",
        field_identifier: "display_name_preference")
    end
    let(:person) { registration.registrant }

    before do
      create(:form_field_resource, form_field: clarity_field, resource: triple_focus)
      create(:form_field_resource, form_field: clarity_field, resource: listening)
      # Make the registrant a scholarship recipient so completion stamps.
      create(:allocation,
        source: create(:scholarship, recipient: person, tasks_completed: true, amount_cents: 100),
        allocatable: registration, amount: 100)
    end

    let(:answers) do
      {
        field.id.to_s => "It changed me",
        anon_field.id.to_s => Person::ANONYMOUS_CONTRIBUTIONS_OPTIONS[true],
        name_field.id.to_s => Person::DISPLAY_NAME_PREFERENCE_LABELS["first_name_only"]
      }
    end
    let(:clarity) do
      { clarity_field.id.to_s => { triple_focus.id.to_s => "Yes", listening.id.to_s => "No" } }
    end

    it "fans the clarity field out to one nil-field answer per resource, snapshotting the sentence" do
      submission = submit(answers, clarity:)

      dynamic = submission.form_answers.where(form_field: nil)
      expect(dynamic.pluck(:question_name_when_answered, :submitted_answer)).to contain_exactly(
        [ "Overall, was the information presented in a clear and concise manner for Triple Focus", "Yes" ],
        [ "Overall, was the information presented in a clear and concise manner for Listening is Art", "No" ]
      )
    end

    # The clarity pair share a prompt and differ only by subtitle, so the snapshot
    # sentence has to keep them apart or one answer overwrites the other.
    it "keeps two same-named fan-out questions on separate answers" do
      part_two = create(:form_field, form:, answer_type: :single_select_radio,
        name: clarity_field.name, subtitle: "Part Two")
      create(:form_field_resource, form_field: part_two, resource: triple_focus)
      clarity_field.update!(subtitle: "Part One")

      submission = submit(answers, clarity: clarity.merge(
        part_two.id.to_s => { triple_focus.id.to_s => "No" }
      ))

      expect(submission.form_answers.where(form_field: nil).pluck(:question_name_when_answered, :submitted_answer))
        .to include(
          [ "Part One: #{clarity_field.name} Triple Focus", "Yes" ],
          [ "Part Two: #{clarity_field.name} Triple Focus", "No" ]
        )
    end

    it "writes the two profile questions through to the Person and reports the changes" do
      service = described_class.call(registration:, callout:, form:, form_params: answers.merge(clarity))

      expect(person.reload.anonymous_contributions).to be(true)
      expect(person.display_name_preference).to eq("first_name_only")
      expect(service.profile_changes).to include(
        anonymous_contributions: [ false, true ],
        display_name_preference: [ "full_name", "first_name_only" ]
      )
    end

    it "stamps completion when a scholarship recipient submits a form on the scholarship callout" do
      scholarship_callout = create(:registration_ticket_callout, event:, builtin_key: "scholarship", form:)
      described_class.call(registration:, callout: scholarship_callout, form:, form_params: answers.merge(clarity))

      expect(registration.reload.post_survey_completed?).to be(true)
    end

    it "does not stamp completion for a form on a non-scholarship callout" do
      submit(answers, clarity:)

      expect(registration.reload.post_survey_completed?).to be(false)
    end

    it "is idempotent on re-submit — updates in place without duplicating answers" do
      submit(answers, clarity:)
      service = described_class.call(registration:, callout:, form:,
        form_params: answers.merge(clarity, field.id.to_s => "Edited"))

      expect(service.submission.form_answers.where(form_field: field).count).to eq(1)
      expect(service.submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Edited")
      expect(service.submission.form_answers.where(form_field: nil).count).to eq(2)
      expect(service.profile_changes).to be_empty
    end
  end
end
