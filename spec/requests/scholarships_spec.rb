require "rails_helper"

RSpec.describe "Scholarships", type: :request do
  let(:admin)        { create(:user, :with_person, super_user: true) }
  let(:event)        { create(:event, cost_cents: 10000) }
  let(:registration) { create(:event_registration, event: event) }
  let(:scholarship)  { create(:scholarship, recipient: registration.registrant, amount_cents: 5000, tasks_completed: true) }
  let!(:allocation)  { create(:allocation, source: scholarship, allocatable: registration, amount: 5000) }

  before { sign_in admin }

  describe "GET /scholarships/:id/edit" do
    it "renders the cost summary with event cost, still owed, and scholarship allocated" do
      get edit_scholarship_path(scholarship)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Event cost")
      expect(response.body).to include("Still owed")
      expect(response.body).to include("Scholarship allocated")
    end

    it "shows this scholarship's allocated amount and wires the live-preview controller" do
      get edit_scholarship_path(scholarship)

      expect(response.body).to include("scholarship-preview")
      expect(response.body).to include("scholarship-preview-target=\"allocated\"")
      # Event cost $100.00 with $50.00 allocated leaves $50.00 owed.
      expect(response.body).to include("$50.00")
    end

    it "shows the registrant's scholarship form answers with a link to the full submission" do
      form = create(:form, name: "Registration Form")
      create(:event_form, event: event, form: form, role: "registration")
      field = create(:form_field, form: form, section: "scholarship",
                     name: "Why do you need a scholarship?", answer_type: :free_form_input_paragraph)
      submission = create(:form_submission, person: registration.registrant, form: form)
      create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "Limited budget")

      get edit_scholarship_path(scholarship)

      expect(response.body).to include("Form submission")
      expect(response.body).to include("Why do you need a scholarship?")
      expect(response.body).to include("Limited budget")
      expect(response.body).to include("View full submission")
      expect(response.body).to include(event_public_registration_path(event, reg: registration.slug))
    end

    it "renders the shared event header: event link, training date, and a profile-linked recipient" do
      get edit_scholarship_path(scholarship)

      # Event title links to the event, with the training date alongside.
      expect(response.body).to include(event.title)
      expect(response.body).to include(event_path(event))
      expect(response.body).to include(event.start_date.in_time_zone(Time.zone).strftime("%b %-d"))

      # Recipient name links to their profile.
      expect(response.body).to include(person_path(registration.registrant))
      expect(response.body).to include(registration.registrant.full_name)
    end
  end

  describe "DELETE /scholarships/:id" do
    it "removes the scholarship and redirects to the manage page with a notice" do
      expect {
        delete scholarship_path(scholarship)
      }.to change(Scholarship, :count).by(-1)

      expect(response).to redirect_to(manage_event_path(event))
      expect(flash[:notice]).to eq("Scholarship removed.")
    end
  end
end
