require "rails_helper"

RSpec.describe "Events::BulkPayments", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, cost_cents: 0) }
  let(:form) { create(:form) }
  # The bulk payment view only renders a known set of "payer" fields, so the
  # min-word rule is exercised through payer_organization (a free-form text field).
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

  def post_bulk_payment(answer)
    post event_bulk_payment_path(event),
         params: { bulk_payment: { form_fields: { org_field.id.to_s => answer } } }
  end

  describe "POST create with a minimum word count" do
    it "rejects an answer with too few words" do
      post_bulk_payment("not quite enough")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be at least 5 words")
    end

    it "does not flag an answer that meets the minimum" do
      post_bulk_payment("this answer easily has plenty of words")

      expect(response.body).not_to include("must be at least 5 words")
    end
  end

  describe "GET new" do
    it "shows the minimum word hint below the field" do
      get new_event_bulk_payment_path(event)

      expect(response.body).to include("Minimum of 5 words.")
    end

    it "renders the field at its configured width" do
      org_field.update!(width: :half)

      get new_event_bulk_payment_path(event)

      expect(response.body).to include("md:col-span-6")
    end
  end

  describe "POST create with credit card payment" do
    let(:admin) { create(:user, :admin, :with_person) }
    let(:event) { create(:event, cost_cents: 15_00) }
    let(:fake_session) { double(url: "https://checkout.stripe.com/test") }

    before do
      fake_processor = double(checkout: fake_session)
      allow_any_instance_of(Person).to receive(:set_payment_processor)
      allow_any_instance_of(Person).to receive(:payment_processor).and_return(fake_processor)
    end

    def payer_params
      {
        payer_first_name_field.id.to_s => "Jane",
        payer_last_name_field.id.to_s => "Doe",
        payer_email_field.id.to_s => "jane@example.com"
      }
    end

    it "redirects to Stripe Checkout when paying by credit card" do
      post event_bulk_payment_path(event),
           params: { bulk_payment: { form_fields: payer_params.merge(
             org_field.id.to_s => "this answer has enough words for validation",
             payment_method_field.id.to_s => "Credit card (now)"
           ) } }

      expect(response).to redirect_to("https://checkout.stripe.com/test")
      expect(response.status).to eq(303)
    end

    it "does not redirect when payment method is not credit card" do
      post event_bulk_payment_path(event),
           params: { bulk_payment: { form_fields: payer_params.merge(
             org_field.id.to_s => "this answer has enough words for validation",
             payment_method_field.id.to_s => "Check"
           ) } }

      expect(response).to have_http_status(:redirect)
      expect(response.location).to match(%r{/bulk_payment/})
      expect(flash[:notice]).to eq("Your payment information has been submitted.")
    end

    it "does not redirect to Stripe when event is free" do
      event.update!(cost_cents: 0)

      post event_bulk_payment_path(event),
           params: { bulk_payment: { form_fields: payer_params.merge(
             org_field.id.to_s => "this answer has enough words for validation"
           ) } }

      expect(response).to have_http_status(:redirect)
      expect(response.location).to match(%r{/bulk_payment/})
    end
  end

  describe "GET new with the seeded bulk payment form" do
    let(:seeded_form) do
      FormBuilderService.new(name: "Bulk Payment", sections: %i[bulk_payment], role: "bulk_payment").call
    end

    before do
      # Payer fields are logged_out_only, so test the public (signed-out) view.
      sign_out admin
      EventForm.where(event: event).destroy_all
      EventForm.create!(event: event, form: seeded_form, role: "bulk_payment")
    end

    it "renders the optional payer phone field" do
      get new_event_bulk_payment_path(event)

      expect(response.body).to include("Phone")
    end

    it "labels the attendee fields with the 'Attendee' prefix" do
      get new_event_bulk_payment_path(event)

      expect(response.body).to include("Attendee first name", "Attendee last name", "Attendee email")
    end
  end

  describe "GET show" do
    # Public submitted-form view, reached by slug via ?reg= (mirrors public
    # registration). Backs to the ticket by default.
    let(:event) { create(:event, :publicly_visible, cost_cents: 1000) }
    let(:payer) { create(:person) }
    let!(:submission) { create(:form_submission, person: payer, form: form, event: event, role: "bulk_payment") }
    let!(:org_answer) do
      submission.form_answers.create!(form_field: org_field, submitted_answer: "Northside Shelter",
                                      question_name_when_answered: org_field.name)
    end

    def get_show
      get event_bulk_payment_path(event, reg: submission.slug)
    end

    context "as a signed-out viewer" do
      before { sign_out admin }

      it "renders the submitted form publicly via the slug" do
        get_show

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Payment submission")
        expect(response.body).to include("Northside Shelter")
      end

      it "backs to the ticket by default" do
        get_show

        expect(response.body).to include(bulk_payment_ticket_path(submission.slug))
        expect(response.body).to include("Back to ticket")
      end

      it "404s for an unknown slug" do
        get event_bulk_payment_path(event, reg: "nope")

        expect(response).to have_http_status(:not_found)
      end

      it "404s for a blank reg, even when a slugless bulk payment exists" do
        submission.update_columns(slug: nil)

        get event_bulk_payment_path(event)

        expect(response).to have_http_status(:not_found)
      end

      it "does not let a signed-out viewer reach a submission by id" do
        get event_bulk_payment_path(event, submission_id: submission.id)

        expect(response).to redirect_to(root_path)
      end
    end

    context "as an admin viewing a slugless submission by id" do
      before { submission.update_columns(slug: nil) }

      it "renders the same submission partial without a ticket back link" do
        get event_bulk_payment_path(event, submission_id: submission.id, return_to: "bulk_payments")

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Payment submission")
        expect(response.body).to include("Northside Shelter")
        expect(response.body).not_to include("Back to ticket")
        expect(response.body).to include("Back to bulk payments")
      end
    end

    context "as an admin arriving from the dashboard" do
      it "shows a Back to ticket link plus a second Back to bulk payments link" do
        get event_bulk_payment_path(event, reg: submission.slug, return_to: "bulk_payments")

        expect(response.body).to include("Back to ticket")
        expect(response.body).to include("Back to bulk payments")
      end
    end
  end

  describe "GET ticket" do
    let(:event) { create(:event, :publicly_visible, cost_cents: 1000, title: "Spring Workshop") }
    let(:payer) { create(:person) }
    let(:attendees_json) do
      [ { "first_name" => "Jordan", "last_name" => "Rivers", "email" => "jordan@example.com" } ].to_json
    end
    let!(:submission) { create(:form_submission, person: payer, form: form, event: event, role: "bulk_payment") }
    let!(:attendees_field) do
      create(:form_field, form: form, answer_type: :free_form_input_one_line,
             field_identifier: "bulk_payment_attendees", name: "Attendees", required: false)
    end

    before do
      submission.form_answers.create!(form_field: attendees_field, submitted_answer: attendees_json,
                                      question_name_when_answered: "Attendees")
      sign_out admin
    end

    def get_ticket
      get bulk_payment_ticket_path(submission.slug)
    end

    it "renders the ticket for the public payer using the slug" do
      get_ticket

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Payment ticket")
      expect(response.body).to include("Spring Workshop")
    end

    it "lists the registrants" do
      get_ticket

      expect(response.body).to include("Jordan Rivers")
      expect(response.body).to include("jordan@example.com")
    end

    it "does not show per-person actions like cancelling a registration" do
      get_ticket

      expect(response.body).not_to include("Cancel registration")
    end

    it "links the invoice back to the ticket" do
      get_ticket

      expect(response.body).to include("return_to=bulk_payment_ticket")
    end

    it "links 'View submission' to the public submission page" do
      get_ticket

      expect(response.body).to include(event_bulk_payment_path(event, reg: submission.slug))
    end

    it "returns 404 for an unknown slug" do
      get bulk_payment_ticket_path("nope")

      expect(response).to have_http_status(:not_found)
    end

    it "adds a Back to bulk payments eyebrow when arriving from the dashboard" do
      get bulk_payment_ticket_path(submission.slug, return_to: "bulk_payments", expand: submission.id)

      expect(response.body).to include("Back to event")
      expect(response.body).to include("Back to bulk payments")
    end

    context "as an admin" do
      before { sign_in admin }

      it "shows the admin allocations section" do
        get_ticket

        expect(response.body).to include("Payment allocations")
      end
    end
  end

  describe "POST resend_confirmation" do
    let(:event) { create(:event, :publicly_visible, cost_cents: 1000) }
    let(:payer) { create(:person, email: "payer@example.com") }
    let!(:submission) { create(:form_submission, person: payer, form: form, event: event, role: "bulk_payment") }

    before { sign_out admin }

    it "re-sends the payer confirmation and returns to the ticket" do
      expect {
        post bulk_payment_resend_confirmation_path(submission.slug)
      }.to change(Notification, :count).by(1)

      expect(response).to redirect_to(bulk_payment_ticket_path(submission.slug))
      expect(flash[:notice]).to eq("Confirmation email sent.")
    end
  end
end
