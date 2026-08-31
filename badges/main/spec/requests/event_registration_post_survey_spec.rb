require "rails_helper"

RSpec.describe "EventRegistration post-event survey toggle", type: :request do
  let(:admin) { create(:user, :with_person, super_user: true) }
  let(:event) { create(:event) }
  let(:registration) { create(:event_registration, event: event) }

  before { sign_in admin }

  it "marks the survey received when it was not, and clears it when it was" do
    expect(registration.post_survey_completed?).to be(false)

    patch toggle_post_survey_event_registration_path(registration)
    expect(registration.reload.post_survey_completed?).to be(true)

    patch toggle_post_survey_event_registration_path(registration)
    expect(registration.reload.post_survey_completed?).to be(false)
  end

  it "does not touch the certificate timestamp (independent toggles)" do
    registration.update!(certificate_sent_at: Time.current)

    patch toggle_post_survey_event_registration_path(registration)

    expect(registration.reload.post_survey_completed?).to be(true)
    expect(registration.certificate_sent_at).to be_present
  end
end
