require "rails_helper"

RSpec.describe "Events::BulkPayments", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, cost_cents: 0) }
  let(:form) { create(:form) }
  # The bulk payment view only renders a known set of "payer" fields, so the
  # min-word rule is exercised through organization_name (a free-form text field).
  let!(:org_field) do
    create(:form_field, form: form, answer_type: :free_form_input_one_line,
           field_identifier: "organization_name", name: "Organization name",
           required: true, min_words: 5)
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
  end
end
