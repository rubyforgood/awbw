require "rails_helper"

# The CE callout's post-training form: built on the generic callout-form flow
# (#2384), but gated so it opens only once the registrant's sign-outs are complete
# and reached from the CE page. Slug is the authorization, no login.
RSpec.describe "Events::Callouts CE form", type: :request do
  let(:event) do
    create(:event, ce_hours_offered: 6, ce_hours_cost_cents: 15_000,
      start_date: Time.zone.local(2026, 7, 23, 9, 0),
      end_date: Time.zone.local(2026, 7, 23, 16, 0))
  end
  let(:registration) { create(:event_registration, event:) }
  let(:form) { create(:form, name: "CE Evaluation") }
  let!(:field) { create(:form_field, form:, name: "How was the training?", required: true) }
  let(:callout) { create(:registration_ticket_callout, event:, builtin_key: "ce_hours", title: "CE hours", form:) }

  before do
    callout
    create(:continuing_education_registration, event_registration: registration)
  end
  after { travel_back }

  describe "the CE callout's form page" do
    it "redirects to the CE page while sign-outs aren't complete" do
      travel_to Time.zone.local(2026, 7, 23, 10, 0) # during the event
      get registration_callout_form_path(registration.slug, callout, return_to: "ce")
      expect(response).to redirect_to(registration_ce_path(registration.slug))
    end

    it "renders the form, returning to the CE page, once sign-outs are complete" do
      travel_to Time.zone.local(2026, 7, 24, 10, 0) # the day after — event has ended
      get registration_callout_form_path(registration.slug, callout, return_to: "ce")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("How was the training?")
      expect(response.body).to include(registration_ce_path(registration.slug))
    end

    it "rejects a submit before sign-outs are complete" do
      travel_to Time.zone.local(2026, 7, 23, 10, 0)
      expect {
        post registration_callout_form_submit_path(registration.slug, callout, form),
          params: { callout_form: { form_fields: { field.id.to_s => "Great" } } }
      }.not_to change { FormSubmission.count }
      expect(response).to redirect_to(registration_ce_path(registration.slug))
    end
  end

  describe "the CE page step" do
    it "links to the form once sign-outs are complete" do
      travel_to Time.zone.local(2026, 7, 24, 10, 0)
      get registration_ce_path(registration.slug)
      expect(response.body).to include(registration_callout_form_path(registration.slug, callout, return_to: "ce"))
      expect(response.body).to include("CE Evaluation")
    end

    it "hides the step during the training" do
      travel_to Time.zone.local(2026, 7, 23, 10, 0)
      get registration_ce_path(registration.slug)
      expect(response.body).not_to include("Complete the form")
    end
  end
end
