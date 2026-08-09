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
    post event_public_registration_path(event),
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

  describe "POST create with an answer longer than its database column" do
    # A real registration form maps answers onto person/address columns; `city`
    # and friends are varchar(255). An over-length answer used to 500 with
    # ActiveRecord::ValueTooLong — it should re-render the form with an error.
    # These optional fields carry the identifiers the service maps to columns.
    %w[first_name last_name primary_email mailing_street mailing_city mailing_state mailing_zip].each do |identifier|
      let!("#{identifier}_field".to_sym) do
        create(:form_field, form: form, field_identifier: identifier, name: identifier.humanize, required: false)
      end
    end

    def fid(key)
      form.form_fields.find_by!(field_identifier: key).id.to_s
    end

    it "re-renders the form with an error instead of raising" do
      expect {
        post event_public_registration_path(event),
             params: { public_registration: { form_fields: {
               essay_field.id.to_s => "this answer has plenty of words",
               fid("first_name") => "Pat",
               fid("last_name") => "Lee",
               fid("primary_email") => "pat@example.com",
               fid("mailing_street") => "1 Main St",
               fid("mailing_city") => "a" * 256,
               fid("mailing_state") => "CA",
               fid("mailing_zip") => "90001"
             } } }
      }.not_to change(EventRegistration, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to match(/city is too long/i)
    end
  end

  describe "POST create error presentation" do
    it "wires the error flash band to auto-scroll into view on failure" do
      post_registration("too few")

      expect(response).to have_http_status(:unprocessable_content)
      # The form-errors Stimulus controller rides on the error flash band so it
      # scrolls itself into view on connect.
      expect(response.body).to match(/role="alert"[^>]*data-controller="form-errors"/)
    end

    it "shows no error band on a successful submission" do
      first = create(:form_field, form: form, field_identifier: "first_name", name: "First name", required: false)
      last = create(:form_field, form: form, field_identifier: "last_name", name: "Last name", required: false)
      email = create(:form_field, form: form, field_identifier: "primary_email", name: "Email", required: false)

      post event_public_registration_path(event),
           params: { public_registration: { form_fields: {
             essay_field.id.to_s => "this answer has plenty of words",
             first.id.to_s => "Pat",
             last.id.to_s => "Lee",
             email.id.to_s => "pat@example.com"
           } } }

      expect(response).to have_http_status(:redirect)
      expect(response.body).not_to include('data-controller="form-errors"')
    end
  end

  describe "POST create with a maximum character count" do
    let!(:bio_field) do
      create(:form_field, form: form, answer_type: :free_form_input_one_line,
             name: "Nickname", required: false, max_characters: 10)
    end

    def post_bio(answer)
      post event_public_registration_path(event),
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
      post event_public_registration_path(event),
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

    context "when the registrant is signed in" do
      let(:user) { create(:user, :with_person) }

      before { sign_in user }

      it "persists the scholarship answers as a scholarship-role submission" do
        expect {
          post_with_scholarship("this scholarship answer clearly has more than eight words total")
        }.to change { FormSubmission.where(role: "scholarship").count }.by(1)

        submission = FormSubmission.where(role: "scholarship").last
        expect(submission.person).to eq(user.person)
        expect(submission.event).to eq(event)
        expect(submission.form_answers.find_by(form_field: scholarship_essay).submitted_answer)
          .to eq("this scholarship answer clearly has more than eight words total")
      end
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
      field = create(:form_field, form: form, answer_type: :single_select_radio,
                     field_identifier: "payment_method", name: "Payment method",
                     required: false)
      FormBuilderService::PAYMENT_METHOD_OPTIONS.each do |option_name|
        field.form_field_answer_options.create!(answer_option: AnswerOption.find_or_create_by!(name: option_name))
      end
      field
    end
    let(:fake_session) { double(url: "https://checkout.stripe.com/test", id: "cs_test_123") }

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
             payment_method_field.id.to_s => "Check"
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
      get new_event_public_registration_path(event)

      expect(response.body).to include("Minimum of 5 words.")
    end

    it "surfaces the CE deadlines on the continuing education section" do
      ce = FormBuilderService.new(name: "CE", sections: %i[continuing_education], role: "continuing_education").call
      event.event_forms.create!(form: ce, role: "continuing_education")
      event.update!(ce_hours_request_deadline: Date.new(2026, 7, 1),
                    ce_payment_due_deadline: ActiveSupport::TimeZone["Pacific Time (US & Canada)"].local(2026, 8, 15, 9, 0))

      get new_event_public_registration_path(event)

      expect(response.body).to include("Request CE credit by")
      expect(response.body).to include("July 1, 2026")
      expect(response.body).to include("Payment due by")
      expect(response.body).to include("August 15, 2026")
    end

    it "renders the CE license type, issuing-state dropdown, expiry date, and provide-later note" do
      ce = FormBuilderService.new(name: "CE", sections: %i[continuing_education], role: "continuing_education").call
      event.event_forms.create!(form: ce, role: "continuing_education")

      get new_event_public_registration_path(event)

      expect(response.body).to include("what is your license type?")
      expect(response.body).to include("In which state was your license issued?")
      expect(response.body).to include("Select a state") # issuing state renders as the US-states dropdown
      expect(response.body).to include('type="date"')     # expiry renders as a date input
      expect(response.body).to include("add or update them later")
    end

    it "renders a structured details panel from known event data when enabled" do
      pacific = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
      start_date = 2.weeks.from_now.in_time_zone(pacific).change(hour: 9)
      end_date   = (start_date + 1.day).change(hour: 16, min: 30)
      event.update!(
        autoshow_registration_details: true,
        start_date: start_date,
        end_date: end_date,
        cost_cents: 150000,
        videoconference_url: "https://zoom.us/j/123",
        videoconference_label: "Zoom"
      )

      get new_event_public_registration_path(event)

      expect(response.body).to include("Platform:")
      expect(response.body).to include("Zoom")
      expect(response.body).to include("Fee:")
      expect(response.body).to include("$1,500")
      expect(response.body).to include("Registration closes")
    end

    it "pluralizes the date and time labels for a multi-day event" do
      pacific = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
      start_date = 2.weeks.from_now.in_time_zone(pacific).change(hour: 9)
      end_date   = (start_date + 1.day).change(hour: 16, min: 30)
      event.update!(autoshow_registration_details: true,
                    start_date: start_date,
                    end_date: end_date)

      get new_event_public_registration_path(event)

      expect(response.body).to include("Dates:")
      expect(response.body).to include("Times:")
    end

    it "uses singular date and time labels for a single-day event" do
      pacific = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
      day = 2.weeks.from_now.in_time_zone(pacific)
      event.update!(autoshow_registration_details: true,
                    start_date: day.change(hour: 9),
                    end_date: day.change(hour: 12))

      get new_event_public_registration_path(event)

      expect(response.body).to include("Date:")
      expect(response.body).to include("Time:")
      expect(response.body).not_to include("Dates:")
      expect(response.body).not_to include("Times:")
    end

    it "renders the event's date and fee hints as grey parentheticals" do
      event.update!(autoshow_registration_details: true,
                    cost_cents: 150000,
                    hint_dates: "must attend both days",
                    hint_registration_cost: "due within 3 weeks of registration")

      get new_event_public_registration_path(event)

      expect(response.body).to include("(must attend both days)")
      expect(response.body).to include("(due within 3 weeks of registration)")
    end

    it "omits the hint parentheticals when the event has none" do
      event.update!(autoshow_registration_details: true, cost_cents: 150000,
                    hint_dates: nil, hint_registration_cost: nil)

      get new_event_public_registration_path(event)

      expect(response.body).not_to include("must attend both days")
      expect(response.body).not_to include("due within 3 weeks")
    end

    it "hides the duplicate hero badges when the details panel is shown" do
      event.update!(autoshow_registration_details: true, cost_cents: 150000)

      get new_event_public_registration_path(event)

      # The fa-ticket cost badge only lives in the hero; the panel owns the fee now.
      expect(response.body).not_to include("fa-ticket")
      expect(response.body).to include("Fee:")
    end

    it "keeps the hero badges when the details panel is off" do
      event.update!(autoshow_registration_details: false, cost_cents: 150000)

      get new_event_public_registration_path(event)

      expect(response.body).to include("fa-ticket")
    end

    it "omits detail rows the event has no data for" do
      event.update!(autoshow_registration_details: true, cost_cents: nil, videoconference_url: nil, location: nil)

      get new_event_public_registration_path(event)

      expect(response.body).not_to include("Platform:")
      expect(response.body).not_to include("Fee:")
    end

    it "hides the details panel when the event has not enabled it" do
      event.update!(autoshow_registration_details: false, cost_cents: 150000)

      get new_event_public_registration_path(event)

      expect(response.body).not_to include("Fee:")
    end

    it "renders a dynamic-option field switched to single choice as radio buttons" do
      # primary_service_area sources its options dynamically from Sector
      # (it stores no answer options of its own). When such a field is changed
      # from checkbox to single-choice radio, the public form must still render
      # the dynamic options — otherwise the question shows up blank.
      sector_a = create(:sector, :published, name: "Healthcare")
      sector_b = create(:sector, :published, name: "Education")
      create(:form_field, form: form, answer_type: :single_select_radio,
             field_identifier: "primary_service_area", name: "Primary sector",
             required: false)

      get new_event_public_registration_path(event)

      expect(response.body.scan(/type="radio"/).size).to be >= 2
      expect(response.body).to include(sector_a.name)
      expect(response.body).to include(sector_b.name)
      expect(response.body).to include(%(value="#{sector_a.id}"))
    end

    it "still renders a dynamic-option field as checkboxes" do
      create(:sector, :published, name: "Healthcare")
      create(:form_field, form: form, answer_type: :multi_select_checkbox,
             field_identifier: "primary_service_area", name: "Primary sector",
             required: false)

      get new_event_public_registration_path(event)

      expect(response.body.scan(/type="checkbox"/).size).to be >= 1
      expect(response.body).to include("Healthcare")
    end

    it "renders the agency website as a text input so bare domains pass validation" do
      website_field = create(:form_field, form: form, answer_type: :free_form_input_one_line,
             field_identifier: "agency_website", name: "Organization website", required: false)

      get new_event_public_registration_path(event)

      input_id = "public_registration_form_fields_#{website_field.id}"
      website_input = response.body[/<input[^>]*id="#{input_id}"[^>]*>/]
      # type="url" makes browsers reject bare domains like "awbw.org"; a text
      # input with inputmode="url" keeps the URL keyboard without that rejection.
      expect(website_input).to include('type="text"')
      expect(website_input).to include('inputmode="url"')
      expect(website_input).not_to include('type="url"')
    end

    it "shows the maximum character hint below the field" do
      create(:form_field, form: form, answer_type: :free_form_input_paragraph,
             name: "Bio", required: false, max_characters: 250)

      get new_event_public_registration_path(event)

      expect(response.body).to include("Maximum of 250 characters.")
    end

    it "renders header and field-label HTML unescaped" do
      create(:form_field, form: form, answer_type: :group_header,
             name: %(Visit <a href="https://awbw.org">our site</a>))
      create(:form_field, form: form, answer_type: :free_form_input_one_line,
             name: "<h2>About you</h2>", required: false)

      get new_event_public_registration_path(event)

      expect(response.body).to include(%(<a href="https://awbw.org">our site</a>))
      expect(response.body).to include("<h2>About you</h2>")
      expect(response.body).to include("rich-label")
    end

    it "renders the form header HTML under the title" do
      form.update!(header: "<strong>Please complete all fields below.</strong>")

      get new_event_public_registration_path(event)

      expect(response.body).to include("<strong>Please complete all fields below.</strong>")
    end

    it "renders a category option's description under its checkbox" do
      category_type = create(:category_type, name: "AgeRange")
      create(:category, :published, category_type: category_type,
             name: "3-5", description: "Preschool and kindergarten")
      create(:form_field, form: form, answer_type: :multi_select_checkbox,
             field_identifier: "primary_age_group", name: "Primary Age Group(s) Served", required: false)

      get new_event_public_registration_path(event)

      expect(response.body).to include("Preschool and kindergarten")
    end

    it "reveals a 'please specify' text input for a radio field's Other option" do
      field = create(:form_field, form: form, answer_type: :single_select_radio,
             name: "Favorite color", required: false)
      [ "Red", "Other" ].each_with_index do |name, i|
        option = create(:answer_option, name: name, position: i)
        create(:form_field_answer_option, form_field: field, answer_option: option)
      end

      get new_event_public_registration_path(event)

      expect(response.body).to include('data-controller="specify-option"')
      expect(response.body).to include('data-specify-option-target="control"')
      expect(response.body).to include('placeholder="Please specify"')
    end

    it "reveals an option-specific text input for a named specify option" do
      field = create(:form_field, form: form, answer_type: :single_select_radio,
             name: "How did you hear about this AWBW training?", required: false)
      [ "Online Search", "Word of Mouth" ].each_with_index do |name, i|
        option = create(:answer_option, name: name, position: i)
        create(:form_field_answer_option, form_field: field, answer_option: option)
      end

      get new_event_public_registration_path(event)

      expect(response.body).to include('data-controller="specify-option"')
      expect(response.body).to include('placeholder="Please list the name of the person"')
      # The named option submits its own label, optionally with the typed text.
      expect(response.body).to match(/data-specify-option-target="control"[\s\S]*?value="Word of Mouth"|value="Word of Mouth"[\s\S]*?data-specify-option-target="control"/)
    end

    it "reveals the text input for a category-backed dynamic field's Other option" do
      # Dynamic fields source options from Category and use the category id as the
      # option value, so the Other option must be detected by its label, not value.
      category_type = create(:category_type, name: "AgeRange")
      create(:category, :published, category_type: category_type, name: "3-5")
      create(:category, :published, category_type: category_type, name: "Other")
      create(:form_field, form: form, answer_type: :multi_select_checkbox,
             field_identifier: "primary_age_group", name: "Primary Age Group(s) Served", required: false)

      get new_event_public_registration_path(event)

      expect(response.body).to include('data-controller="specify-option"')
      expect(response.body).to include('placeholder="Please specify"')
      # The Other option submits the literal "Other", not the category id.
      expect(response.body).to include('data-specify-option-target="control"')
      expect(response.body).to match(/data-specify-option-target="control"[\s\S]*?value="Other"|value="Other"[\s\S]*?data-specify-option-target="control"/)
    end

    it "omits the Other option from a dropdown field" do
      field = create(:form_field, form: form, answer_type: :single_select_dropdown,
             name: "Favorite color", required: false)
      [ "Red", "Other" ].each_with_index do |name, i|
        option = create(:answer_option, name: name, position: i)
        create(:form_field_answer_option, form_field: field, answer_option: option)
      end

      get new_event_public_registration_path(event)

      expect(response.body).to include("<option value=\"Red\"")
      expect(response.body).not_to include("<option value=\"Other\"")
    end

    it "does not add the specify controller to fields without a specify option" do
      field = create(:form_field, form: form, answer_type: :single_select_radio,
             name: "Favorite color", required: false)
      option = create(:answer_option, name: "Red", position: 0)
      create(:form_field_answer_option, form_field: field, answer_option: option)

      get new_event_public_registration_path(event)

      expect(response.body).not_to include('data-controller="specify-option"')
    end

    it "re-checks Other and prefills the text input after a validation error" do
      field = create(:form_field, form: form, answer_type: :single_select_radio,
             name: "Favorite color", required: true)
      [ "Red", "Other" ].each_with_index do |name, i|
        option = create(:answer_option, name: name, position: i)
        create(:form_field_answer_option, form_field: field, answer_option: option)
      end
      required = create(:form_field, form: form, answer_type: :free_form_input_one_line,
             name: "Name", required: true)

      post event_public_registration_path(event),
           params: { public_registration: { form_fields: {
             field.id.to_s => "Other: chartreuse",
             required.id.to_s => ""
           } } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('value="chartreuse"')
      # The Other radio is re-checked and its text input is not hidden.
      expect(response.body).not_to match(/placeholder="Please specify"[^>]*\bhidden\b/)
    end
  end

  describe "GET new payment method options" do
    # A paid event so the payment section is not stripped from the form.
    let(:event) { create(:event, cost_cents: 150_00) }
    let!(:payment_method_field) do
      field = create(:form_field, form: form, answer_type: :single_select_radio,
                     field_identifier: "payment_method", name: "Payment method",
                     required: false)
      FormBuilderService::PAYMENT_METHOD_OPTIONS.each do |option_name|
        field.form_field_answer_options.create!(answer_option: AnswerOption.find_or_create_by!(name: option_name))
      end
      field
    end

    it "does not offer 'Other' as a payment method" do
      expect(FormBuilderService::PAYMENT_METHOD_OPTIONS).not_to include("Other")
    end

    it "renders the remaining payment methods without 'Other'" do
      get new_event_public_registration_path(event)

      expect(response.body).to include(%(value="Check"))
      expect(response.body).not_to include(%(value="Other"))
    end

    it "still shows the payment method (without 'Other') for a scholarship registrant" do
      get new_event_public_registration_path(event, scholarship_requested: "true")

      expect(response.body).to include(%(value="Check"))
      expect(response.body).not_to include(%(value="Other"))
    end
  end

  describe "GET show" do
    let(:person) { create(:person) }

    before { create(:form_submission, person: person, form: form, event: event) }

    it "renders header and field-label HTML unescaped on the response page" do
      create(:form_field, form: form, answer_type: :group_header, name: "<strong>Your details</strong>")
      create(:form_field, form: form, answer_type: :free_form_input_one_line, name: "<em>Name</em>", required: false)

      get event_public_registration_path(event, person_id: person.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("<strong>Your details</strong>")
      expect(response.body).to include("<em>Name</em>")
    end

    it "shows the question wording captured at submission time, not the reworded label" do
      submission = FormSubmission.find_by(person: person, form: form)
      submission.form_answers.create!(form_field: essay_field, submitted_answer: "my reasons",
                                      question_name_when_answered: "Why do you want to attend?")
      essay_field.update!(name: "Reworded after submission")

      get event_public_registration_path(event, person_id: person.id)

      expect(response.body).to include("Why do you want to attend?")
      expect(response.body).not_to include("Reworded after submission")
    end

    it "renders an uploaded file answer as an image preview and download link" do
      upload_field = create(:form_field, :file_upload, form: form, name: "Photo of your creation")
      submission = FormSubmission.find_by(person: person, form: form)
      answer = submission.form_answers.create!(form_field: upload_field, submitted_answer: "sample.png")
      answer.build_asset.tap do |asset|
        asset.file.attach(io: File.open(Rails.root.join("spec/fixtures/files/sample.png")),
                          filename: "sample.png", content_type: "image/png")
        asset.save!
      end

      get event_public_registration_path(event, person_id: person.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Photo of your creation")
      expect(response.body).to include("sample.png")
      expect(response.body).to include(rails_blob_path(answer.uploaded_file, only_path: true))
    end

    context "when the registrant filled out a separate scholarship form" do
      let(:scholarship_form) { create(:form, role: "scholarship") }
      let!(:scholarship_field) do
        create(:form_field, form: scholarship_form, answer_type: :free_form_input_paragraph,
               name: "Why do you need a scholarship?", required: false)
      end

      before do
        EventForm.create!(event: event, form: scholarship_form, role: "scholarship")
        submission = FormSubmission.create!(person: person, form: scholarship_form, event: event, role: "scholarship")
        submission.form_answers.create!(form_field: scholarship_field,
                                        submitted_answer: "Our agency training budget was cut.")
      end

      it "shows the scholarship application answers alongside the registration responses" do
        get event_public_registration_path(event, person_id: person.id)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Why do you need a scholarship?")
        expect(response.body).to include("Our agency training budget was cut.")
      end
    end

    context "when the scholarship answers were captured on the registration submission" do
      let(:scholarship_form) { create(:form, role: "scholarship") }
      let!(:scholarship_field) do
        create(:form_field, form: scholarship_form, section: "scholarship",
               answer_type: :free_form_input_paragraph, name: "Why do you need a scholarship?", required: false)
      end

      before do
        EventForm.create!(event: event, form: scholarship_form, role: "scholarship")
        # No separate scholarship submission — the answer hangs off the
        # registration submission, on a scholarship-form field.
        reg_submission = FormSubmission.find_by(person: person, form: form)
        reg_submission.form_answers.create!(form_field: scholarship_field,
                                            submitted_answer: "Our agency training budget was cut.")
      end

      it "still surfaces them in the scholarship application card" do
        get event_public_registration_path(event, person_id: person.id)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Scholarship application")
        expect(response.body).to include("Why do you need a scholarship?")
        expect(response.body).to include("Our agency training budget was cut.")
      end
    end

    it "does not render a scholarship section when there is no scholarship submission" do
      get event_public_registration_path(event, person_id: person.id)

      expect(response.body).not_to include("Scholarship application")
    end

    context "when reached from the admin org-linking popup" do
      let(:admin) { create(:user, :admin) }
      let!(:registration) { create(:event_registration, event: event, registrant: person) }

      before { sign_in admin }

      it "shows a back link to the org popup, carrying its own return_to" do
        get event_public_registration_path(event, person_id: person.id,
          return_to: "link_organization", link_org_return_to: "registrants")

        expect(response.body).to include("Back to linked organizations")
        expect(response.body).to include(link_organization_event_registration_path(registration, return_to: "registrants"))
      end

      it "omits the org-popup back link without the return_to marker" do
        get event_public_registration_path(event, person_id: person.id)

        expect(response.body).not_to include("Back to linked organizations")
      end
    end

    context "when viewed from the admin registrants roster" do
      let(:admin) { create(:user, :admin) }
      let!(:registration) { create(:event_registration, event: event, registrant: person) }

      before { sign_in admin }

      it "returns the eyebrow to the registrant's row instead of the ticket" do
        get event_public_registration_path(event, person_id: person.id,
          return_to: "registrants", return_registration_id: registration.id)

        expect(response.body).to include("Back to registrants")
        expect(response.body).to include("registrant-row-#{registration.id}")
        expect(response.body).to include("highlight=#{registration.id}")
        expect(response.body).not_to include("Back to ticket")
      end
    end
  end
end
