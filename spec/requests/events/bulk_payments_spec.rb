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
    create(:form_field, form: form, answer_type: :single_select_radio,
           field_identifier: "payment_method", name: "Payment method",
           required: false)
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
             payment_method_field.id.to_s => "Pay later"
           ) } }

      expect(response).to have_http_status(:redirect)
      expect(response.location).to match(%r{/events/#{event.id}/bulk_payment})
      expect(flash[:notice]).to eq("Your bulk payment information has been submitted.")
    end

    it "does not redirect to Stripe when event is free" do
      event.update!(cost_cents: 0)

      post event_bulk_payment_path(event),
           params: { bulk_payment: { form_fields: payer_params.merge(
             org_field.id.to_s => "this answer has enough words for validation"
           ) } }

      expect(response).to have_http_status(:redirect)
      expect(response.location).to match(%r{/events/#{event.id}/bulk_payment})
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
end
