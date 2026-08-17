require "rails_helper"

RSpec.describe PublicFormSubmission do
  let(:form) { create(:form, slug: "volunteer-interest", published: true) }

  let!(:first_name_field) { create(:form_field, form: form, name: "First name", field_identifier: "first_name") }
  let!(:last_name_field)  { create(:form_field, form: form, name: "Last name", field_identifier: "last_name") }
  let!(:email_field)      { create(:form_field, form: form, name: "Email", field_identifier: "primary_email") }
  let!(:question_field)   { create(:form_field, form: form, name: "Why do you want to volunteer?") }

  def params_for(first: "Sam", last: "Rivera", email: "sam@example.com", answer: "I care.")
    {
      first_name_field.id.to_s => first,
      last_name_field.id.to_s => last,
      email_field.id.to_s => email,
      question_field.id.to_s => answer
    }
  end

  it "creates a person, submission, and answers" do
    result = nil
    expect { result = described_class.call(form: form, form_params: params_for) }
      .to change(Person, :count).by(1)
      .and change(FormSubmission, :count).by(1)

    expect(result.success?).to be(true)
    expect(result.person.email).to eq("sam@example.com")
    expect(result.form_submission.role).to eq("public")
    expect(result.form_submission.event).to be_nil

    answer = result.form_submission.form_answers.find_by(form_field: question_field)
    expect(answer.submitted_answer).to eq("I care.")
  end

  it "reuses an existing person matched on email + last name" do
    existing = create(:person, first_name: "Sam", last_name: "Rivera", email: "sam@example.com")

    expect { described_class.call(form: form, form_params: params_for) }
      .to change(Person, :count).by(0)
      .and change(FormSubmission, :count).by(1)

    expect(FormSubmission.last.person).to eq(existing)
  end

  it "fails with a friendly error when the form can't identify the respondent" do
    result = described_class.call(form: form, form_params: params_for(email: ""))

    expect(result.success?).to be(false)
    expect(result.errors).to include(PublicFormSubmission::IDENTITY_MISSING_MESSAGE)
    expect(FormSubmission.count).to eq(0)
  end

  it "sends a confirmation to the submitter and an FYI to admin" do
    expect { described_class.call(form: form, form_params: params_for) }
      .to change { Notification.where(kind: "form_submission_confirmation").count }.by(1)
      .and change { Notification.where(kind: "form_submission_confirmation_fyi").count }.by(1)

    confirmation = Notification.find_by(kind: "form_submission_confirmation")
    expect(confirmation.recipient_email).to eq("sam@example.com")
    expect(confirmation.recipient_role).to eq("person")
  end

  it "records mailing-list consent once when the consent question is answered" do
    consent_field = create(:form_field, form: form, name: "Email me updates",
                           answer_type: :multi_select_checkbox, field_identifier: "communication_consent")
    params = params_for.merge(consent_field.id.to_s => [ "Yes, keep me posted" ])

    result = described_class.call(form: form, form_params: params)

    expect(result.person.mailing_list_consent_at).to be_present
    expect(result.person.mailing_list_consent_source).to include(form.display_name)
  end
end
