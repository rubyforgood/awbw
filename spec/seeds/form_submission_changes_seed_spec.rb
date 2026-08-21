require "rails_helper"

RSpec.describe "dev seed: form_submission_changes" do
  it "gives Maria Johnson a stamped post-registration edit trail on the changes page" do
    maria = create(:person, first_name: "Maria", last_name: "Johnson")
    form = create(:form)
    event = create(:event)
    create(:event_form, :registration, event: event, form: form)
    org = create(:organization, name: "Helping Hands")
    create(:affiliation, person: maria, organization: org)

    load Rails.root.join("db/seeds/dev/form_submission_changes.rb")

    submission = FormSubmission.find_by!(person: maria, role: "registration")
    changes = FormSubmissionChanges.new(submission)

    expect(changes.edited?).to be(true)
    expect(changes.edited_count).to eq(6)
    expect(changes.edited_groups.map(&:record_type)).to contain_exactly("Person", "Organization")
  end

  it "is idempotent — re-running adds no duplicate events" do
    create(:person, first_name: "Maria", last_name: "Johnson")
    event = create(:event)
    create(:event_form, :registration, event: event, form: create(:form))
    create(:organization)

    load Rails.root.join("db/seeds/dev/form_submission_changes.rb")
    submission = FormSubmission.find_by!(role: "registration")
    first_count = Ahoy::Event.where("properties->>'$.form_submission_id' = ?", submission.id.to_s).count

    load Rails.root.join("db/seeds/dev/form_submission_changes.rb")
    second_count = Ahoy::Event.where("properties->>'$.form_submission_id' = ?", submission.id.to_s).count

    expect(second_count).to eq(first_count)
  end
end
