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

RSpec.describe "/scholarships (grant-funded flow)", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:donor) { create(:organization, name: "Helping Hands") }
  let(:grant) { create(:grant, donor:, amount_cents: 100_000) }
  let(:recipient) { create(:person, first_name: "Bob", last_name: "Barker") }

  before { sign_in admin }

  describe "GET /scholarships/new?grant_id=" do
    it "renders the grant-funded form showing the funder" do
      get new_scholarship_path(grant_id: grant.id, return_to: "grant_show")
      expect(response).to be_successful
      expect(response.body).to include("Funder")
      expect(response.body).to include("Helping Hands")
    end
  end

  describe "POST /scholarships?grant_id=" do
    let(:valid_params) do
      { scholarship: { recipient_id: recipient.id, amount_dollars: "250" } }
    end

    it "creates a grant-funded scholarship and returns to the grant show page" do
      expect {
        post scholarships_path(grant_id: grant.id, return_to: "grant_show"), params: valid_params
      }.to change(Scholarship, :count).by(1)

      scholarship = Scholarship.last
      expect(scholarship.grant).to eq(grant)
      expect(scholarship.recipient).to eq(recipient)
      expect(scholarship.amount_cents).to eq(25_000)
      expect(response).to redirect_to(grant_path(grant))
    end

    it "returns to the grant edit page when launched from there" do
      post scholarships_path(grant_id: grant.id, return_to: "grant_edit"), params: valid_params
      expect(response).to redirect_to(edit_grant_path(grant))
    end

    it "rejects an amount that exceeds the grant's available funds" do
      expect {
        post scholarships_path(grant_id: grant.id, return_to: "grant_show"),
             params: { scholarship: { recipient_id: recipient.id, amount_dollars: "1500" } }
      }.not_to change(Scholarship, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /scholarships/:id with grant return context" do
    let(:scholarship) { create(:scholarship, grant:, recipient:, amount_cents: 10_000) }

    it "updates and returns to the grant show page" do
      patch scholarship_path(scholarship, return_to: "grant_show"),
            params: { scholarship: { amount_dollars: "300" } }
      expect(scholarship.reload.amount_cents).to eq(30_000)
      expect(response).to redirect_to(grant_path(grant))
    end
  end

  describe "grant pages list associated scholarships" do
    it "shows the scholarship on the grant show page" do
      create(:scholarship, grant:, recipient:, amount_cents: 10_000)
      get grant_path(grant)
      expect(response.body).to include("Bob Barker")
      expect(response.body).to include("Add scholarship")
    end
  end
end
