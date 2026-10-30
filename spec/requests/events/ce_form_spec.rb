require "rails_helper"

# The CE callout's post-training form: built on the generic callout-form flow
# (#2384), but gated so it opens only once the registrant's sign-outs are complete,
# and rendered inline on the CE page in the shared callout-form card. Slug is the
# authorization, no login.
RSpec.describe "Events::Callouts CE form", type: :request do
  let(:event) do
    create(:event, ce_hours_offered: 6, ce_hours_cost_cents: 15_000,
      start_date: Time.zone.local(2026, 7, 23, 9, 0),
      end_date: Time.zone.local(2026, 7, 23, 16, 0))
  end
  let(:registration) { create(:event_registration, event:) }
  let(:form) { create(:form, name: "CE Evaluation", anonymous: true) }
  let!(:field) { create(:form_field, form:, name: "How was the training?", required: true) }
  let(:callout) { create(:registration_ticket_callout, event:, builtin_key: "ce_hours", title: "CE hours", form:) }

  before do
    callout
    create(:continuing_education_registration, event_registration: registration)
  end
  after { travel_back }

  describe "the CE callout's generic form page" do
    it "sends the registrant to the CE page, where the form lives" do
      travel_to Time.zone.local(2026, 7, 24, 10, 0) # the day after — event has ended
      get registration_callout_form_path(registration.slug, callout)
      expect(response).to redirect_to(registration_ce_path(registration.slug, anchor: "ce-form"))
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
    it "renders the form inline once sign-outs are complete" do
      travel_to Time.zone.local(2026, 7, 24, 10, 0)
      get registration_ce_path(registration.slug)
      expect(response.body).to include("CE Evaluation").and include("How was the training?")
      expect(response.body).to include(registration_callout_form_submit_path(registration.slug, callout, form))
    end

    it "breaks the form out of the CE page's turbo frame" do
      travel_to Time.zone.local(2026, 7, 24, 10, 0)
      get registration_ce_path(registration.slug)
      html_form = Nokogiri::HTML(response.body).at_css("form[action='#{registration_callout_form_submit_path(registration.slug, callout, form)}']")
      expect(html_form["data-turbo-frame"]).to eq("_top")
    end

    it "folds the callout's Details while the form is open to fill" do
      callout.update!(description: "<p>CE requirements</p>")
      travel_to Time.zone.local(2026, 7, 24, 10, 0)

      get registration_ce_path(registration.slug)

      toggle = Nokogiri::HTML(response.body).css("details").find { |d| d.at_css("summary")&.text&.include?("Details") }
      expect(toggle).to be_present
      expect(toggle["open"]).to be_nil
      expect(toggle.text).to include("CE requirements")
    end

    it "leaves the Details open during the training, before the form" do
      callout.update!(description: "<p>CE requirements</p>")
      travel_to Time.zone.local(2026, 7, 23, 10, 0)

      get registration_ce_path(registration.slug)

      expect(response.body).to include("CE requirements")
      expect(Nokogiri::HTML(response.body).css("summary").map(&:text).join).not_to include("Details")
    end

    it "hides the step during the training" do
      travel_to Time.zone.local(2026, 7, 23, 10, 0)
      get registration_ce_path(registration.slug)
      expect(response.body).not_to include("How was the training?")
    end
  end

  describe "submitting the CE form" do
    before { travel_to Time.zone.local(2026, 7, 24, 10, 0) }

    def submit_form
      post registration_callout_form_submit_path(registration.slug, callout, form),
        params: { callout_form: { form_fields: { field.id.to_s => "Great" } } }
    end

    it "records the answers with no person and still meets the certificate's form requirement" do
      submit_form

      expect(FormSubmission.last.person).to be_nil
      expect(registration.reload.ce_form_requirement_met?).to be(true)
    end

    it "returns to the CE page's form" do
      submit_form

      expect(response).to redirect_to(registration_ce_path(registration.slug, anchor: "ce-form"))
    end

    it "folds the card to completed without offering to edit the answers" do
      submit_form

      get registration_ce_path(registration.slug)

      expect(response.body).to include("Completed").and include("submitted anonymously")
      expect(response.body).not_to include("Edit responses")
      expect(response.body).not_to include("Please complete this form")
    end
  end
end
