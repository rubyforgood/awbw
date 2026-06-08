require "rails_helper"

RSpec.describe "Events::PublicRegistrations", type: :request do
  # A guest registering on a free event so we exercise the bare create path
  # without payment or auth.
  let(:event) { create(:event, cost_cents: 0) }
  let(:form) { create(:form) }
  let!(:essay_field) do
    create(:form_field, form: form, answer_type: :free_form_input_paragraph,
           name: "Tell us why you'd like to attend", required: true, min_words: 5)
  end

  before { EventForm.create!(event: event, form: form, role: "registration") }

  def post_registration(answer)
    post event_registration_form_path(event),
         params: { public_registration: { form_fields: { essay_field.id.to_s => answer } } }
  end

  describe "POST create with a minimum word count" do
    it "rejects an answer with too few words" do
      expect {
        post_registration("not quite enough")
      }.not_to change(EventRegistration, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be at least 5 words")
    end

    it "does not flag an answer that meets the minimum" do
      post_registration("this answer has plenty of words")

      expect(response.body).not_to include("must be at least 5 words")
    end
  end

  describe "POST create with a maximum character count" do
    let!(:bio_field) do
      create(:form_field, form: form, answer_type: :free_form_input_one_line,
             name: "Nickname", required: false, max_characters: 10)
    end

    def post_bio(answer)
      post event_registration_form_path(event),
           params: { public_registration: { form_fields: {
             essay_field.id.to_s => "this answer has plenty of words",
             bio_field.id.to_s => answer
           } } }
    end

    it "rejects an answer that is too long" do
      expect {
        post_bio("a" * 11)
      }.not_to change(EventRegistration, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be 10 characters or fewer")
    end

    it "does not flag an answer within the maximum" do
      post_bio("short")

      expect(response.body).not_to include("must be 10 characters or fewer")
    end
  end

  describe "POST create enforces the same settings on the scholarship form" do
    let(:scholarship_form) { create(:form, role: "scholarship") }
    let!(:scholarship_essay) do
      create(:form_field, form: scholarship_form, answer_type: :free_form_input_paragraph,
             name: "Describe your need", required: true, min_words: 8)
    end

    before { EventForm.create!(event: event, form: scholarship_form, role: "scholarship") }

    def post_with_scholarship(scholarship_answer)
      post event_registration_form_path(event),
           params: {
             scholarship_requested: "true",
             public_registration: { form_fields: {
               essay_field.id.to_s => "this answer has plenty of words",
               scholarship_essay.id.to_s => scholarship_answer
             } }
           }
    end

    it "rejects a scholarship answer with too few words" do
      expect {
        post_with_scholarship("too short here")
      }.not_to change(EventRegistration, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be at least 8 words")
    end

    it "does not flag a scholarship answer that meets the minimum" do
      post_with_scholarship("this scholarship answer clearly has more than eight words total")

      expect(response.body).not_to include("must be at least 8 words")
    end
  end

  describe "POST create with credit card payment" do
    let(:user) { create(:user, :with_person) }
    let(:event) { create(:event, cost_cents: 15_00) }
    let(:form) { create(:form) }
    let!(:essay_field) do
      create(:form_field, form: form, answer_type: :free_form_input_paragraph,
             name: "Tell us why", required: true, min_words: 5)
    end
    let!(:payment_method_field) do
      create(:form_field, form: form, answer_type: :multiple_choice_radio,
             field_identifier: "payment_method", name: "Payment method",
             required: false)
    end
    let(:fake_session) { double(url: "https://checkout.stripe.com/test") }

    before do
      sign_in user
      fake_processor = double(checkout: fake_session)
      allow_any_instance_of(Person).to receive(:set_payment_processor)
      allow_any_instance_of(Person).to receive(:payment_processor).and_return(fake_processor)
    end

    it "redirects to Stripe Checkout when paying by credit card" do
      post event_public_registration_path(event),
           params: { public_registration: { form_fields: {
             essay_field.id.to_s => "this answer has enough words for validation",
             payment_method_field.id.to_s => "Credit card (now)"
           } } }

      expect(response).to redirect_to("https://checkout.stripe.com/test")
      expect(response.status).to eq(303)
    end

    it "does not redirect when payment method is not credit card" do
      post event_public_registration_path(event),
           params: { public_registration: { form_fields: {
             essay_field.id.to_s => "this answer has enough words for validation",
             payment_method_field.id.to_s => "Pay later"
           } } }

      expect(response).to have_http_status(:redirect)
      expect(response.location).to match(%r{/registration/})
      expect(flash[:notice]).to eq("You have been successfully registered!")
    end

    it "does not redirect to Stripe when event is free" do
      event.update!(cost_cents: 0)

      post event_public_registration_path(event),
           params: { public_registration: { form_fields: {
             essay_field.id.to_s => "this answer has enough words for validation"
           } } }

      expect(response).to have_http_status(:redirect)
      expect(response.location).to match(%r{/registration/})
    end
  end

  describe "GET new" do
    it "shows the minimum word hint below the field" do
      get new_event_registration_form_path(event)

      expect(response.body).to include("Minimum of 5 words.")
    end

    it "renders a dynamic-option field switched to single choice as radio buttons" do
      # primary_service_area sources its options dynamically from Sector
      # (it stores no answer options of its own). When such a field is changed
      # from checkbox to single-choice radio, the public form must still render
      # the dynamic options — otherwise the question shows up blank.
      sector_a = create(:sector, :published, name: "Healthcare")
      sector_b = create(:sector, :published, name: "Education")
      create(:form_field, form: form, answer_type: :single_select_radio,
             field_identifier: "primary_service_area", name: "Primary service area",
             required: false)

      get new_event_registration_form_path(event)

      expect(response.body.scan(/type="radio"/).size).to be >= 2
      expect(response.body).to include(sector_a.name)
      expect(response.body).to include(sector_b.name)
      expect(response.body).to include(%(value="#{sector_a.id}"))
    end

    it "still renders a dynamic-option field as checkboxes" do
      create(:sector, :published, name: "Healthcare")
      create(:form_field, form: form, answer_type: :multi_select_checkbox,
             field_identifier: "primary_service_area", name: "Primary service area",
             required: false)

      get new_event_registration_form_path(event)

      expect(response.body.scan(/type="checkbox"/).size).to be >= 1
      expect(response.body).to include("Healthcare")
    end

    it "shows the maximum character hint below the field" do
      create(:form_field, form: form, answer_type: :free_form_input_paragraph,
             name: "Bio", required: false, max_characters: 250)

      get new_event_registration_form_path(event)

      expect(response.body).to include("Maximum of 250 characters.")
    end

    it "renders header and field-label HTML unescaped" do
      create(:form_field, form: form, answer_type: :group_header,
             name: %(Visit <a href="https://awbw.org">our site</a>))
      create(:form_field, form: form, answer_type: :free_form_input_one_line,
             name: "<h2>About you</h2>", required: false)

      get new_event_registration_form_path(event)

      expect(response.body).to include(%(<a href="https://awbw.org">our site</a>))
      expect(response.body).to include("<h2>About you</h2>")
      expect(response.body).to include("rich-label")
    end

    it "renders the form header HTML under the title" do
      form.update!(header: "<strong>Please complete all fields below.</strong>")

      get new_event_registration_form_path(event)

      expect(response.body).to include("<strong>Please complete all fields below.</strong>")
    end

    it "renders a workshop setting option's description under its checkbox" do
      category_type = create(:category_type, name: "WorkshopEnvironment")
      create(:category, :published, category_type: category_type,
             name: "Clinical setting", description: "Community mental health, outpatient, etc")
      create(:form_field, form: form, answer_type: :multi_select_checkbox,
             field_identifier: "workshop_environments", name: "Workshop Settings", required: false)

      get new_event_public_registration_path(event)

      expect(response.body).to include("Community mental health, outpatient, etc")
    end
  end

  describe "GET show" do
    let(:person) { create(:person) }

    before { create(:form_submission, person: person, form: form) }

    it "renders header and field-label HTML unescaped on the response page" do
      create(:form_field, form: form, answer_type: :group_header, name: "<strong>Your details</strong>")
      create(:form_field, form: form, answer_type: :free_form_input_one_line, name: "<em>Name</em>", required: false)

      get event_registration_form_path(event, person_id: person.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("<strong>Your details</strong>")
      expect(response.body).to include("<em>Name</em>")
    end
  end
end
