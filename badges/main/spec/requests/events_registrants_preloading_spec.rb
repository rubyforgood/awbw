require "rails_helper"

# The roster reads each CE registrant's certificate availability (readiness + the
# certificate cell), which checks the CE callout's (anonymous) form completion and logged
# attendance time. Those re-query per row unless the controller preloads them, so
# this guards the preload: adding CE registrants must not add queries.
RSpec.describe "Event registrants CE certificate preloading", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, :ended, ce_hours_offered: 6) }
  let(:form) { create(:form, name: "CE Evaluation", anonymous: true) }
  let!(:required_field) { create(:form_field, form:, name: "How was it?", required: true) }

  before do
    create(:registration_ticket_callout, event:, builtin_key: "ce_hours", title: "CE hours", form:)
    sign_in admin
  end

  def add_ce_registrants(count)
    count.times do
      registration = create(:event_registration, event:, status: "attended")
      create(:continuing_education_registration, event_registration: registration, cost_cents: 0,
        professional_license: create(:professional_license, person: registration.registrant))
      create(:event_attendance_time_entry, event_registration: registration,
        signed_in_at: 13.days.ago, signed_out_at: 13.days.ago + 8.hours)
      create(:form_completion, person: registration.registrant, form:, event:)
    end
  end

  def queries_for_roster
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get registrants_event_path(event) }
    expect(response).to be_successful
    count
  end

  it "does not issue more queries as more CE registrants are listed" do
    add_ce_registrants(2)
    queries_for_roster # warm up: the first request also loads the signed-in user
    baseline = queries_for_roster

    add_ce_registrants(4)
    expect(queries_for_roster).to eq(baseline)
  end

  it "shows their CE certificates as available" do
    add_ce_registrants(1)
    get registrants_event_path(event)
    expect(Capybara.string(response.body)).to have_css("##{ActionView::RecordIdentifier.dom_id(EventRegistration.last, :ce_certificate_issued)}", text: "Available")
  end
end
