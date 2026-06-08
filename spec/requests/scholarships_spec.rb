require "rails_helper"

RSpec.describe "Scholarships", type: :request do
  let(:admin)        { create(:user, :with_person, super_user: true) }
  let(:event)        { create(:event, cost_cents: 10000) }
  let(:registration) { create(:event_registration, event: event) }
  let(:scholarship)  { create(:scholarship, recipient: registration.registrant, amount_cents: 5000, tasks_completed: true) }
  let!(:allocation)  { create(:allocation, source: scholarship, allocatable: registration, amount: 5000) }

  before { sign_in admin }

  describe "GET /scholarships/:id/edit" do
    it "renders the cost summary with event cost, scholarship amount, and still owed" do
      get edit_scholarship_path(scholarship)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Event cost")
      expect(response.body).to include("Scholarship amount")
      expect(response.body).to include("Still owed")
    end

    it "flags a completed scholarship as allocated and wires the live-preview controller" do
      get edit_scholarship_path(scholarship)

      expect(response.body).to include("scholarship-preview")
      expect(response.body).to include("scholarship-preview-target=\"amountBox\"")
      # Tasks completed → the $50.00 amount is allocated to the registration.
      expect(response.body).to include("$50.00 allocated to registration")
      # Event cost $100.00 with $50.00 allocated leaves $50.00 owed.
      expect(response.body).to include("$50.00")
    end

    it "renders the scholarship amount field with a non-negative minimum" do
      get edit_scholarship_path(scholarship)

      expect(response.body).to match(/<input(?=[^>]*name="scholarship\[amount_dollars\]")(?=[^>]*min="0")[^>]*>/)
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
      # The header renders event times in the viewer's zone (Pacific by default),
      # so assert the date in that same zone rather than the test's UTC default.
      display_zone = "Pacific Time (US & Canada)"
      expect(response.body).to include(event.start_date.in_time_zone(display_zone).strftime("%b %-d"))

      # Recipient name links to their profile.
      expect(response.body).to include(person_path(registration.registrant))
      expect(response.body).to include(registration.registrant.full_name)
    end

    it "lists only grants with funds remaining in the picker, with their remaining-of-total funds" do
      funded = create(:grant, name: "Open Fund", amount_cents: 100_000)
      exhausted = create(:grant, name: "Spent Fund", amount_cents: 20_000)
      create(:scholarship, grant: exhausted, amount_cents: 20_000)

      get edit_scholarship_path(scholarship)

      expect(response.body).to include("Open Fund")
      # Compact remaining/total funds carried on the option for the picker badge.
      expect(response.body).to include("$1k of $1k available")
      expect(response.body).not_to include("Spent Fund")
    end
  end

  describe "PATCH /scholarships/:id from the registration View link" do
    it "returns to the event registration edit page" do
      patch scholarship_path(scholarship, return_to: "registration"),
            params: { scholarship: { amount_dollars: "40" } }

      expect(response).to redirect_to(edit_event_registration_path(registration))
    end
  end

  describe "POST /scholarships from the registration Add link" do
    it "returns to the event registration edit page on create (symmetric with View)" do
      expect {
        post scholarships_path(allocatable_sgid: registration.to_sgid.to_s, return_to: "registration"),
             params: { scholarship: { amount_dollars: "40" } }
      }.to change(Scholarship, :count).by(1)

      expect(response).to redirect_to(edit_event_registration_path(registration))
    end
  end

  describe "comments and communications on the edit page" do
    it "renders the comments section" do
      get edit_scholarship_path(scholarship)
      expect(response.body).to include("Scholarship comments")
      expect(response.body).to include("Add comment")
    end

    it "saves a new comment authored by the current user" do
      expect {
        patch scholarship_path(scholarship),
              params: { scholarship: { comments_attributes: { "0" => { body: "Followed up by email" } } } }
      }.to change { scholarship.comments.count }.by(1)

      comment = scholarship.comments.order(:created_at).last
      expect(comment.body).to eq("Followed up by email")
      expect(comment.created_by).to eq(admin)
    end

    it "logs a notification against the scholarship recipient" do
      expect {
        patch scholarship_path(scholarship),
              params: { scholarship: { notifications_attributes: { "0" => { email_subject: "Called recipient" } } } }
      }.to change { scholarship.notifications.count }.by(1)

      note = scholarship.notifications.last
      expect(note.noticeable).to eq(scholarship)
      expect(note.email_subject).to eq("Called recipient")
      expect(note.recipient_email).to eq(scholarship.recipient.preferred_email.presence || "n/a")
    end
  end

  describe "DELETE /scholarships/:id" do
    it "removes the scholarship and redirects to the registrants page with a notice" do
      expect {
        delete scholarship_path(scholarship)
      }.to change(Scholarship, :count).by(-1)

      expect(response).to redirect_to(registrants_event_path(event))
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

    it "re-renders the form with the validation error shown when the amount exceeds the grant" do
      patch scholarship_path(scholarship, return_to: "grant_show"),
            params: { scholarship: { amount_dollars: "5000" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("prevented this scholarship from being saved")
      expect(response.body).to include("would exceed the grant")
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

# A scholarship can be both event-funded (an allocation against a registration)
# and grant-funded. Navigation must follow the context the user came from —
# carried via the return_to param — rather than always preferring the event.
RSpec.describe "Scholarships (grant + event dual context)", type: :request do
  let(:admin)        { create(:user, :with_person, super_user: true) }
  let(:event)        { create(:event, cost_cents: 10_000) }
  let(:registration) { create(:event_registration, event: event) }
  let(:grant)        { create(:grant, amount_cents: 100_000) }
  let(:scholarship) do
    create(:scholarship, recipient: registration.registrant, grant: grant,
           amount_cents: 5_000, tasks_completed: true)
  end
  let!(:allocation) { create(:allocation, source: scholarship, allocatable: registration, amount: 5_000) }

  before { sign_in admin }

  describe "arriving from the grant page (return_to=grant_show)" do
    it "renders a back link to the grant, not the event registration" do
      get edit_scholarship_path(scholarship, return_to: "grant_show")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("href=\"#{grant_path(grant)}\"")
    end

    it "returns to the grant page on destroy" do
      delete scholarship_path(scholarship, return_to: "grant_show")
      expect(response).to redirect_to(grant_path(grant))
    end
  end

  describe "arriving from the event registration (no grant context)" do
    it "returns to the event registrants page on destroy" do
      delete scholarship_path(scholarship)
      expect(response).to redirect_to(registrants_event_path(event))
    end
  end
end
