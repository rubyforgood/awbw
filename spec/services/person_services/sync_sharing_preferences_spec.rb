require "rails_helper"

RSpec.describe PersonServices::SyncSharingPreferences do
  let(:person) { create(:person, profile_is_searchable: true, profile_show_email: false, profile_show_bio: true) }
  let(:form) { FormBuilderService.new(name: "Profile prefs", sections: %i[profile_display_preferences content_sharing_preferences]).call }

  def params_for(answers)
    answers.to_h { |identifier, label| [ form.form_fields.find_by!(field_identifier: identifier).id.to_s, label ] }
  end

  it "writes each answered profile display toggle onto the person" do
    sync = described_class.call(person:, form:, form_params: params_for(
      "profile_is_searchable" => "No", "profile_show_email" => "Yes"
    ))

    expect(person.reload).to have_attributes(profile_is_searchable: false, profile_show_email: true, profile_show_bio: true)
    expect(sync.changes).to eq(profile_is_searchable: [ true, false ], profile_show_email: [ false, true ])
  end

  it "matches a Yes/No answer regardless of case and surrounding space" do
    described_class.call(person:, form:, form_params: params_for("profile_show_bio" => " no "))

    expect(person.reload.profile_show_bio).to be(false)
  end

  it "leaves the toggles alone when unanswered" do
    described_class.call(person:, form:, form_params: {})

    expect(person.reload).to have_attributes(profile_is_searchable: true, profile_show_email: false, profile_show_bio: true)
  end

  it "still writes the content sharing answers" do
    described_class.call(person:, form:, form_params: params_for(
      "anonymous_contributions" => Person::ANONYMOUS_CONTRIBUTIONS_OPTIONS[true],
      "display_name_preference" => Person::DISPLAY_NAME_PREFERENCE_LABELS["first_name_only"]
    ))

    expect(person.reload).to have_attributes(anonymous_contributions: true, display_name_preference: "first_name_only")
  end

  it "asks every profile display toggle in the question library" do
    expect(form.form_fields.where.not(field_identifier: nil).pluck(:field_identifier))
      .to include(*Person::PROFILE_VISIBILITY_LABELS.keys)
  end
end
