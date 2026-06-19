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
      # Tasks completed → the $50 amount is allocated to the registration.
      expect(response.body).to include("$50 allocated to registration")
      # Event cost $100 with $50 allocated leaves $50 owed.
      expect(response.body).to include("$50")
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

    it "shows answers submitted on the event's dedicated scholarship form" do
      scholarship_form = create(:form, name: "Scholarship Application")
      create(:event_form, event: event, form: scholarship_form, role: "scholarship")
      field = create(:form_field, form: scholarship_form, section: "scholarship",
                     name: "How much can you contribute?", answer_type: :free_form_input_one_line)
      submission = create(:form_submission, person: registration.registrant, form: scholarship_form, role: "scholarship")
      create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "$250")

      get edit_scholarship_path(scholarship)

      expect(response.body).to include("Form submission")
      expect(response.body).to include("How much can you contribute?")
      expect(response.body).to include("$250")
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

  describe "GET /scholarships/new" do
    it "shows the registrant's scholarship form answers with a link to the full submission" do
      form = create(:form, name: "Registration Form")
      create(:event_form, event: event, form: form, role: "registration")
      field = create(:form_field, form: form, section: "scholarship",
                     name: "Why do you need a scholarship?", answer_type: :free_form_input_paragraph)
      submission = create(:form_submission, person: registration.registrant, form: form)
      create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "Limited budget")

      get new_scholarship_path(allocatable_sgid: registration.to_sgid.to_s, return_to: "registrants")

      expect(response.body).to include("Form submission")
      expect(response.body).to include("Why do you need a scholarship?")
      expect(response.body).to include("Limited budget")
      expect(response.body).to include("View full submission")
      expect(response.body).to include(event_public_registration_path(event, reg: registration.slug))
    end

    it "shows answers submitted on the event's dedicated scholarship form" do
      scholarship_form = create(:form, name: "Scholarship Application")
      create(:event_form, event: event, form: scholarship_form, role: "scholarship")
      field = create(:form_field, form: scholarship_form, section: "scholarship",
                     name: "How much can you contribute?", answer_type: :free_form_input_one_line)
      submission = create(:form_submission, person: registration.registrant, form: scholarship_form, role: "scholarship")
      create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "$250")

      get new_scholarship_path(allocatable_sgid: registration.to_sgid.to_s, return_to: "registration")

      expect(response.body).to include("Form submission")
      expect(response.body).to include("How much can you contribute?")
      expect(response.body).to include("$250")
    end
  end

  describe "PATCH /scholarships/:id from the registration Edit link" do
    it "returns to the event registration edit page" do
      patch scholarship_path(scholarship, return_to: "registration"),
            params: { scholarship: { amount_dollars: "40" } }

      expect(response).to redirect_to(edit_event_registration_path(registration))
    end
  end

  describe "PATCH /scholarships/:id from the registrants roster (no return_to)" do
    it "returns to the registrants roster" do
      patch scholarship_path(scholarship),
            params: { scholarship: { amount_dollars: "40" } }

      expect(response).to redirect_to(registrants_event_path(event))
    end
  end

  describe "PATCH /scholarships/:id from the recipients page Edit link" do
    it "returns to the recipients page, scrolled to the participant card" do
      patch scholarship_path(scholarship, return_to: "recipients", participant: registration.slug),
            params: { scholarship: { amount_dollars: "40" } }

      expect(response).to redirect_to(recipients_event_path(event, anchor: "participant-#{registration.slug}"))
    end
  end

  describe "scholarship agreement toggle" do
    it "renders the agreement toggle on the edit form" do
      get edit_scholarship_path(scholarship)

      expect(response.body).to include("Scholarship agreement")
      expect(response.body).to match(/name="scholarship\[agreement_signed\]"/)
    end

    it "persists the agreement_signed flag through update" do
      expect(scholarship.agreement_signed?).to be(false)

      patch scholarship_path(scholarship), params: { scholarship: { agreement_signed: "1" } }

      expect(scholarship.reload.agreement_signed?).to be(true)
    end

    it "shows the agreement status on the show page" do
      scholarship.update!(agreement_signed: true)
      get scholarship_path(scholarship)

      expect(response.body).to include("Agreement signed")
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

  describe "back link follows the page the user came from" do
    it "links the new page back to the registrants roster (anchored to the row) when return_to=registrants" do
      get new_scholarship_path(allocatable_sgid: registration.to_sgid.to_s, return_to: "registrants")

      expect(response.body).to include("href=\"#{registrants_event_path(event, highlight: registration.id, anchor: "registrant-row-#{registration.id}")}\"")
      expect(response.body).not_to include("href=\"#{edit_event_registration_path(registration)}\"")
    end

    it "links the new page back to the registration when return_to=registration" do
      get new_scholarship_path(allocatable_sgid: registration.to_sgid.to_s, return_to: "registration")

      expect(response.body).to include("href=\"#{edit_event_registration_path(registration)}\"")
    end

    it "links the edit page back to the registrants roster (anchored to the row) when return_to=registrants" do
      get edit_scholarship_path(scholarship, return_to: "registrants")

      expect(response.body).to include("href=\"#{registrants_event_path(event, highlight: registration.id, anchor: "registrant-row-#{registration.id}")}\"")
    end

    it "links the edit page back to the registration when return_to=registration" do
      get edit_scholarship_path(scholarship, return_to: "registration")

      expect(response.body).to include("href=\"#{edit_event_registration_path(registration)}\"")
    end

    it "links the edit page back to the recipients page when return_to=recipients" do
      get edit_scholarship_path(scholarship, return_to: "recipients", participant: registration.slug)

      expect(response.body).to include("href=\"#{recipients_event_path(event, anchor: "participant-#{registration.slug}")}\"")
    end
  end

  describe "comments and communications on the edit page" do
    it "renders the comments section" do
      get edit_scholarship_path(scholarship)
      expect(response.body).to include("Scholarship comments")
      expect(response.body).to include("Add comment")
    end

    it "saves a new comment with its topic, authored by the current user" do
      expect {
        patch scholarship_path(scholarship),
              params: { scholarship: { comments_attributes: { "0" => { topic: "Follow-up", body: "Followed up by email" } } } }
      }.to change { scholarship.comments.count }.by(1)

      comment = scholarship.comments.order(:created_at).last
      expect(comment.body).to eq("Followed up by email")
      expect(comment.topic).to eq("Follow-up")
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

    it "edits an existing logged notification in place" do
      note = create(:notification, noticeable: scholarship,
                                   recipient_email: scholarship.recipient.preferred_email.presence || "n/a",
                                   email_subject: "Called recipient", channel: "email", kind: "manual_log",
                                   recipient_role: "person", notification_type: 0)

      patch scholarship_path(scholarship),
            params: { scholarship: { notifications_attributes: { "0" => { id: note.id, email_subject: "Emailed recipient" } } } }

      expect(note.reload.email_subject).to eq("Emailed recipient")
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

    it "returns to the recipients page when deleted from there" do
      delete scholarship_path(scholarship, return_to: "recipients", participant: registration.slug)

      expect(response).to redirect_to(recipients_event_path(event, anchor: "participant-#{registration.slug}"))
    end
  end

  describe "PATCH /scholarships/:id/toggle_tasks" do
    let(:tasks_status_id) { ActionView::RecordIdentifier.dom_id(scholarship, :tasks_status) }

    it "flips the tasks-completed flag without affecting the allocation amount" do
      patch toggle_tasks_scholarship_path(scholarship)

      expect(scholarship.reload.tasks_completed?).to be(false)
      expect(allocation.reload.amount).to eq(5000)
    end

    it "flips an outstanding scholarship to completed without affecting the allocation" do
      scholarship.update!(tasks_completed: false)

      patch toggle_tasks_scholarship_path(scholarship)

      expect(scholarship.reload.tasks_completed?).to be(true)
      expect(allocation.reload.amount).to eq(5000)
    end

    it "replaces just the status pill in response to a turbo-stream request" do
      patch toggle_tasks_scholarship_path(scholarship),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(<turbo-stream action="replace" target="#{tasks_status_id}">))
      expect(response.body).to include("Tasks outstanding")
    end

    it "redirects back to the recipients page for a non-Turbo request" do
      patch toggle_tasks_scholarship_path(scholarship)

      expect(response).to redirect_to(recipients_event_path(event))
    end

    context "as a non-admin" do
      let(:member) { create(:user, :with_person) }

      before { sign_in member }

      it "is not authorized and leaves the scholarship unchanged" do
        patch toggle_tasks_scholarship_path(scholarship)

        expect(response).to redirect_to(root_path)
        expect(scholarship.reload.tasks_completed?).to be(true)
      end
    end
  end
end

RSpec.describe "GET /scholarships (index)", type: :request do
  let(:admin) { create(:user, :admin) }

  describe "authorization" do
    it "redirects non-admins away from the index" do
      sign_in create(:user)
      get scholarships_path
      expect(response).to redirect_to(root_path)
    end
  end

  context "as an admin" do
    before { sign_in admin }

    it "renders a grid grouped by funder and grant, with each derived column" do
      org = create(:organization, name: "Prevail")
      create(:address, addressable: org, city: "Stockton", state: "CA")
      recipient = create(:person, first_name: "Carmen", last_name: "Gomez")
      create(:affiliation, person: recipient, organization: org, title: "Facilitator")
      training = create(:event, title: "TAC251", facilitator_training: true)
      create(:event_registration, registrant: recipient, event: training, status: "attended")

      donor = create(:organization, name: "JDI Foundation")
      grant = create(:grant, name: "JDI", donor: donor, amount_cents: 1_000_000)
      create(:scholarship, grant: grant, recipient: recipient, amount_cents: 150_000)

      get scholarships_path

      expect(response).to be_successful
      expect(response.body).to include("JDI Foundation")  # funder group
      expect(response.body).to include("JDI")             # grant group
      expect(response.body).to include("Carmen Gomez")    # recipient
      expect(response.body).to include("Prevail")         # program (org via facilitator affiliation)
      expect(response.body).to include("Stockton, CA")    # program location
      expect(response.body).to include("TAC251")          # attended facilitator training
      expect(response.body).to include("New")             # program status — first facilitator for the org
    end

    it "collects grant-free scholarships under an Unfunded group" do
      create(:scholarship, grant: nil, recipient: create(:person, first_name: "Jane", last_name: "Doe"))

      get scholarships_path

      expect(response.body).to include("Unfunded")
      expect(response.body).to include("Jane Doe")
    end

    it "links a grant group's grant back to the scholarship index via from_scholarships" do
      grant = create(:grant, name: "Marisla")
      create(:scholarship, grant: grant)

      get scholarships_path

      expect(response.body).to include(grant_path(grant, from_scholarships: true))
    end

    it "filters to a single recipient when recipient_id is given" do
      recipient = create(:person, first_name: "Carmen", last_name: "Gomez")
      other = create(:person, first_name: "Jane", last_name: "Doe")
      create(:scholarship, recipient: recipient)
      create(:scholarship, recipient: other)

      get scholarships_path(recipient_id: recipient.id)

      expect(response.body).to include("Filtered to")
      expect(response.body).to include("Carmen Gomez")
      expect(response.body).not_to include("Jane Doe")
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
