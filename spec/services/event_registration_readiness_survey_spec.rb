require "rails_helper"

RSpec.describe EventRegistrationReadiness, "post-event survey gating" do
  let(:event) { create(:event, cost_cents: 1000) }
  let(:registration) { create(:event_registration, event: event, status: "attended") }
  subject(:readiness) { described_class.new(registration) }

  def link_org(reg)
    create(:event_registration_organization, event_registration: reg, organization: create(:organization))
  end

  # A scholarship covering the full cost makes the recipient paid-in-full and, with
  # tasks complete, clears every pre-event and post-event check except the survey.
  def award_scholarship(reg, amount: 1000)
    scholarship = create(:scholarship, recipient: reg.registrant, tasks_completed: true, amount_cents: amount)
    create(:allocation, source: scholarship, allocatable: reg, amount: amount)
  end

  def open_recipient_survey(hidden: false, display_from: 1.day.ago)
    event.registration_ticket_callouts.create!(
      builtin_key: "scholarship_recipients_survey", title: "Scholarship recipients survey",
      callout_type: "action", hidden: hidden, display_from: display_from
    )
  end

  before do
    link_org(registration)
    award_scholarship(registration)
  end

  it "is survey_pending once the survey is live and unsubmitted" do
    open_recipient_survey

    expect(readiness.status).to eq(:survey_pending)
    expect(readiness.certifiable?).to be(false)
    expect(readiness.completed?).to be(false)
    expect(readiness.status_issues).to include("Post-event survey outstanding")
  end

  it "advances to certificate_due once the survey is submitted" do
    open_recipient_survey
    registration.mark_post_survey_completed!

    expect(readiness.status).to eq(:certificate_due)
  end

  it "does not gate when the survey callout is unpublished" do
    open_recipient_survey(hidden: true)

    expect(readiness.status).to eq(:certificate_due)
  end

  it "does not gate before the drip date" do
    open_recipient_survey(display_from: 1.day.from_now)

    expect(readiness.status).to eq(:certificate_due)
  end

  it "orders survey_pending between ready and certificate_due" do
    expect(EventRegistrationReadiness::STATUS_ORDER.index(:survey_pending))
      .to be_between(
        EventRegistrationReadiness::STATUS_ORDER.index(:ready) + 1,
        EventRegistrationReadiness::STATUS_ORDER.index(:certificate_due) - 1
      )
  end

  it "never gates a non-recipient" do
    non_recipient = create(:event_registration, event: event, status: "attended")
    create(:event_registration_organization, event_registration: non_recipient, organization: create(:organization))
    create(:allocation,
      source: create(:payment, amount_cents: 1000, amount_cents_remaining: 1000),
      allocatable: non_recipient, amount: 1000)
    open_recipient_survey

    expect(described_class.new(non_recipient).status).to eq(:certificate_due)
  end
end
