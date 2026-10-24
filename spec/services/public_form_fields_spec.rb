require "rails_helper"

RSpec.describe PublicFormFields do
  let(:form) { create(:form) }
  let(:person) { create(:person, first_name: "Sam", last_name: "Rivera", email: "sam@example.com") }

  let!(:header) do
    create(:form_field, form: form, name: "About you", answer_type: :group_header,
           section: "about_you", visibility: :logged_out_only)
  end
  let!(:first_name_field) do
    create(:form_field, form: form, name: "First name", field_identifier: "first_name", required: true,
           section: "about_you", visibility: :logged_out_only)
  end
  let!(:question_field) { create(:form_field, form: form, name: "Why do you want to volunteer?") }

  it "shows every question to a logged-out respondent" do
    expect(described_class.new(form: form, person: nil).visible).to eq([ header, first_name_field, question_field ])
  end

  it "skips answered Logged out only questions and their emptied section header for a logged-in respondent" do
    expect(described_class.new(form: form, person: person).visible).to eq([ question_field ])
  end

  it "keeps the section header while a question under it is still shown" do
    create(:form_field, form: form, name: "Pronouns", field_identifier: "pronouns",
           section: "about_you", visibility: :logged_out_only)

    expect(described_class.new(form: form, person: person).visible).to include(header)
  end

  it "prefills only the identity questions it shows" do
    first_name_field.update!(visibility: :always_ask)

    expect(described_class.new(form: form, person: person).prefill_values).to eq(first_name_field.id => "Sam")
  end
end
