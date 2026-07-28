require "rails_helper"

RSpec.describe "Events::BulkPayments", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, cost_cents: 0) }
  let(:form) { create(:form) }
  let!(:org_field) do
    create(:form_field, form: form, answer_type: :free_form_input_one_line,
           field_identifier: "payer_organization", name: "Organization",
           required: true, min_words: 5)
  end
  let!(:payment_method_field) do
    field = create(:form_field, form: form, answer_type: :single_select_radio,
                   field_identifier: "payment_method", name: "Payment method",
                   required: false)
    FormBuilderService::PAYMENT_METHOD_OPTIONS.each do |option_name|
      field.form_field_answer_options.create!(answer_option: AnswerOption.find_or_create_by!(name: option_name))
    end
    field
  end
  let!(:payer_first_name_field) do
    create(:form_field, form: form, answer_type: :free_form_input_one_line,
           field_identifier: "payer_first_name", name: "Payer first name",
           required: false)
  end
  let!(:payer_last_name_field) do
    create(:form_field, form: form, answer_type: :free_form_input_one_line,
           field_identifier: "payer_last_name", name: "Payer last name",
           required: false)
  end
  let!(:payer_email_field) do
    create(:form_field, form: form, answer_type: :free_form_input_one_line,
           field_identifier: "payer_email", name: "Payer email",
           required: false)
  end

  before do
    EventForm.create!(event: event, form: form, role: "bulk_payment")
    sign_in admin
  end

  describe "GET /events/:id/bulk_payments (admin dashboard)" do
    let(:event) { create(:event, cost_cents: 2500) }
    let(:payer) { create(:person) }
    let!(:submission) { create(:form_submission, person: payer, form: form, event: event, role: "bulk_payment") }
    let!(:attendees_field) do
      create(:form_field, form: form, field_identifier: "number_of_attendees", name: "Attendees")
    end

    it "shows the submitted amount even when no payment has landed" do
      submission.form_answers.create!(form_field: attendees_field, submitted_answer: "3")

      get bulk_payments_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("$75")
    end

    it "shows the recorded payment amount when a payment exists" do
      submission.form_answers.create!(form_field: attendees_field, submitted_answer: "3")
      create(:payment, person: payer, form_submission: submission,
             amount_cents: 5000, amount_cents_remaining: 5000)

      get bulk_payments_event_path(event)

      expect(response.body).to include("$50")
    end

    it "renders the targeted submission's row expanded when given an expand param" do
      get bulk_payments_event_path(event, expand: submission.id)

      expect(response.body).to include("id=\"payment-card-#{submission.id}\"")
      expect(response.body).to include("data-dropdown-target=\"expand\"")
    end

    it "renders rows collapsed without an expand param" do
      get bulk_payments_event_path(event)

      expect(response.body).to match(/id="payment-details-#{submission.id}"\s+class="hidden/)
      expect(response.body).not_to match(/id="payment-arrow-#{submission.id}"[^>]*rotate-180/)
    end


    it "shows a grey \"Paid\" instead of an orange balance when the registration is fully covered" do
      attendee = create(:person, first_name: "Paid", last_name: "Infull", email: "paid.infull@example.com")
      registration = create(:event_registration, event: event, registrant: attendee, status: "registered")
      create(:form_field, form: form, field_identifier: "bulk_payment_attendees", name: "Attendees list")
      submission.form_answers.create!(
        form_field: form.form_fields.find_by(field_identifier: "bulk_payment_attendees"),
        submitted_answer: [ { first_name: "Paid", last_name: "Infull", email: "paid.infull@example.com" } ].to_json
      )
      create(:allocation, source: create(:payment, amount_cents: 2500, amount_cents_remaining: 2500),
             allocatable: registration, amount: 2500)
      submission.link_registration!(registration.id)

      get bulk_payments_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("text-gray-500 whitespace-nowrap\">Paid<")
      expect(response.body).not_to include("$0.00")
    end

    it "does not show the removed new-allocation dropdown" do
      get bulk_payments_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("New allocation")
    end
  end

  describe "POST /events/:id/allocate_bulk_payment" do
    let(:event) { create(:event) }
    let(:payer) { create(:person) }
    let!(:submission) { create(:form_submission, person: payer, form: form, event: event, role: "bulk_payment") }
    let!(:payment) { create(:payment, person: payer, form_submission: submission,
                            amount_cents: 1000, amount_cents_remaining: 1000) }
    let(:registrant) { create(:person) }
    let!(:event_registration) { create(:event_registration, event: event, registrant: registrant) }

    let(:valid_params) do
      { payment_id: payment.id, event_registration_id: event_registration.id, amount_dollars: "5.00" }
    end

    it "rejects unauthenticated request" do
      sign_out admin
      post allocate_bulk_payment_event_path(event), params: valid_params
      expect(response).to redirect_to(new_user_session_path)
    end

    it "rejects non-admin request" do
      sign_out admin
      sign_in create(:user)
      post allocate_bulk_payment_event_path(event), params: valid_params
      expect(response).to redirect_to(root_path)
    end

    it "creates an allocation and returns turbo_stream" do
      expect {
        post allocate_bulk_payment_event_path(event), params: valid_params, as: :turbo_stream
      }.to change(Allocation, :count).by(1)

      expect(payment.reload.amount_cents_remaining).to eq(500)
      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include("Allocation successful")
    end

    context "when the allocation pays a matched registration in full" do
      let(:event) { create(:event, cost_cents: 500) }
      let(:registrant) { create(:person, email: "match@example.com") }
      let!(:attendees_field) do
        create(:form_field, form: form, field_identifier: "bulk_payment_attendees", name: "Attendees")
      end

      before do
        submission.form_answers.create!(
          form_field: attendees_field,
          submitted_answer: [ { first_name: registrant.first_name, last_name: registrant.last_name, email: "match@example.com" } ].to_json
        )
        submission.link_registration!(event_registration.id)
      end

      it "re-renders the card with refreshed totals and hides the inline allocate box for that registration" do
        post allocate_bulk_payment_event_path(event),
             params: { payment_id: payment.id, event_registration_id: event_registration.id, amount_dollars: "5.00" },
             as: :turbo_stream

        expect(response.body).to include("payment-card-#{submission.id}")
        expect(response.body).to include("rotate-180")
        expect(response.body).to include(">Paid</span>")
        expect(response.body.scan(">Allocate</button>").size).to eq(0)
      end
    end

    it "shows alert when event_registration_id is blank" do
      params = valid_params.merge(event_registration_id: "")
      expect {
        post allocate_bulk_payment_event_path(event), params: params, as: :turbo_stream
      }.not_to change(Allocation, :count)

      expect(response.body).to include("Please select a registrant")
    end

    it "shows alert when event_registration_id is invalid" do
      params = valid_params.merge(event_registration_id: 999999)
      expect {
        post allocate_bulk_payment_event_path(event), params: params, as: :turbo_stream
      }.not_to change(Allocation, :count)

      expect(response.body).to include("Please select a registrant")
    end

    it "shows alert when amount is zero" do
      params = valid_params.merge(amount_dollars: "0.00")
      expect {
        post allocate_bulk_payment_event_path(event), params: params, as: :turbo_stream
      }.not_to change(Allocation, :count)

      expect(response.body).to include("Amount must be greater than $0.00")
    end

    it "shows alert when amount exceeds remaining balance" do
      params = valid_params.merge(amount_dollars: "20.00")
      expect {
        post allocate_bulk_payment_event_path(event), params: params, as: :turbo_stream
      }.not_to change(Allocation, :count)

      expect(response.body).to include("Amount exceeds remaining balance")
    end

    it "shows alert when event registration is already fully paid" do
      large_payment = create(:payment, person: payer, form_submission: submission,
                             amount_cents: 2000, amount_cents_remaining: 2000)
      create(:allocation, source: large_payment, allocatable: event_registration, amount: 1099)

      params = { payment_id: large_payment.id, event_registration_id: event_registration.id, amount_dollars: "5.00" }
      expect {
        post allocate_bulk_payment_event_path(event), params: params, as: :turbo_stream
      }.not_to change(Allocation, :count)

      expect(response.body).to include("already fully paid")
    end
  end

  describe "POST /events/:id/link_bulk_payment" do
    let(:event) { create(:event) }
    let(:payer) { create(:person) }
    let!(:submission) { create(:form_submission, person: payer, form: form, event: event, role: "bulk_payment") }
    let(:registrant) { create(:person) }
    let!(:event_registration) { create(:event_registration, event: event, registrant: registrant) }

    it "adds the registration id to the submission metadata" do
      post link_bulk_payment_event_path(event),
           params: { submission_id: submission.id, event_registration_id: event_registration.id },
           as: :turbo_stream

      expect(submission.reload.linked_registration_ids).to eq([event_registration.id])
      expect(response).to have_http_status(:ok)
    end

    it "does not duplicate an existing link" do
      submission.link_registration!(event_registration.id)

      expect {
        post link_bulk_payment_event_path(event),
             params: { submission_id: submission.id, event_registration_id: event_registration.id },
             as: :turbo_stream
      }.not_to change { submission.reload.linked_registration_ids }
    end

    it "re-renders the card expanded" do
      post link_bulk_payment_event_path(event),
           params: { submission_id: submission.id, event_registration_id: event_registration.id },
           as: :turbo_stream

      expect(response.body).to include("payment-card-#{submission.id}")
    end

    it "redirects to bulk_payments with HTML format" do
      post link_bulk_payment_event_path(event),
           params: { submission_id: submission.id, event_registration_id: event_registration.id }

      expect(response).to redirect_to(bulk_payments_event_path(event))
    end

    it "shows an alert for a missing registration" do
      post link_bulk_payment_event_path(event),
           params: { submission_id: submission.id, event_registration_id: 0 },
           as: :turbo_stream

      expect(response.body).to include("Registration not found")
    end
  end

  describe "DELETE /events/:id/unlink_bulk_payment" do
    let(:event) { create(:event) }
    let(:payer) { create(:person) }
    let!(:submission) { create(:form_submission, person: payer, form: form, event: event, role: "bulk_payment") }
    let(:registrant) { create(:person) }
    let!(:event_registration) { create(:event_registration, event: event, registrant: registrant) }

    before do
      submission.link_registration!(event_registration.id)
    end

    it "removes the registration id from the submission metadata" do
      delete unlink_bulk_payment_event_path(event),
             params: { submission_id: submission.id, event_registration_id: event_registration.id },
             as: :turbo_stream

      expect(submission.reload.linked_registration_ids).to be_empty
      expect(response).to have_http_status(:ok)
    end

    it "re-renders the card expanded" do
      delete unlink_bulk_payment_event_path(event),
             params: { submission_id: submission.id, event_registration_id: event_registration.id },
             as: :turbo_stream

      expect(response.body).to include("payment-card-#{submission.id}")
    end

    it "redirects to bulk_payments with HTML format" do
      delete unlink_bulk_payment_event_path(event),
             params: { submission_id: submission.id, event_registration_id: event_registration.id }

      expect(response).to redirect_to(bulk_payments_event_path(event))
    end
  end
end
