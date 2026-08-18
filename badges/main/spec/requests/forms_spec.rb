require "rails_helper"

RSpec.describe "Forms", type: :request do
  let(:admin) { create(:user, super_user: true) }
  let(:user) { create(:user) }

  describe "GET /forms" do
    context "as admin" do
      before { sign_in admin }

      it "lists standalone forms" do
        create(:form, :standalone, name: "My Form")
        get forms_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("My Form")
      end

      it "shows the public link for a published form" do
        create(:form, :standalone, name: "Volunteer", slug: "volunteer", published: true)
        get forms_path
        expect(response.body).to include(public_form_path("volunteer"))
        expect(response.body).to include("/f/volunteer")
      end

      it "marks an event-connected unpublished form as an event form, not 'Not published'" do
        form = create(:form, :standalone, name: "Reg Form")
        EventForm.create!(form: form, event: create(:event), role: "registration")
        get forms_path
        expect(response.body).to include("Event form")
      end

      it "shows both the public link and event-form chips when a form is both" do
        form = create(:form, :standalone, name: "Dual Form", slug: "dual", published: true)
        EventForm.create!(form: form, event: create(:event), role: "registration")
        get forms_path
        expect(response.body).to include("/f/dual")
        expect(response.body).to include("Event form")
      end

      it "marks a standalone form with no events and no public link as not published" do
        create(:form, :standalone, name: "Orphan Form")
        get forms_path
        expect(response.body).to include("Not published")
      end

      it "has no Delete link" do
        form = create(:form, :standalone, name: "My Form")
        get forms_path
        expect(response.body).not_to include(">Delete<")
      end
    end

    context "as regular user" do
      before { sign_in user }

      it "denies access" do
        get forms_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /forms/smart_form_settings" do
    context "as admin" do
      before { sign_in admin }

      it "documents an identifier alongside what it does" do
        get smart_form_settings_forms_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Smart form settings")
        expect(response.body).to include("agency_name")
        expect(response.body).to include("Looked up against existing organizations by exact name")
      end

      it "lists the identifiers that only store an answer" do
        get smart_form_settings_forms_path

        expect(response.body).to include("referral_source")
        expect(response.body).to include("Identifiers that do nothing extra")
      end

      # Reached from a form editor, so it has to offer a way back to that editor
      # rather than dropping the admin on the generic forms list.
      it "links back to the form it was opened from" do
        form = create(:form, :standalone, name: "Reg form")

        get smart_form_settings_forms_path(form_id: form.id)

        expect(response.body).to include(edit_form_path(form))
        expect(response.body).to include("Back to Reg form")
      end

      it "offers no back link when it was not opened from a form" do
        get smart_form_settings_forms_path

        expect(response.body).not_to include("Back to")
      end
    end

    context "as regular user" do
      before { sign_in user }

      it "denies access" do
        get smart_form_settings_forms_path

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /forms/new" do
    before { sign_in admin }

    it "shows section checkboxes" do
      get new_form_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Person identifier")
      expect(response.body).to include("Scholarship")
    end

    it "lists each section's fields behind an expandable toggle" do
      get new_form_path
      expect(response.body).to include("First Name")
      expect(response.body).to include("Confirm Email")
      expect(response.body).to include('data-controller="expandable-card"')
    end
  end

  describe "POST /forms" do
    before { sign_in admin }

    it "creates a form with selected sections" do
      post forms_path, params: {
        name: "Custom Form",
        sections: %w[person_identifier consent]
      }
      form = Form.last
      expect(form.name).to eq("Custom Form")
      expect(form.sections).to eq(%w[person_identifier consent])
      expect(response).to redirect_to(edit_sections_form_path(form))
    end

    it "rejects when no sections selected" do
      post forms_path, params: { name: "Empty", sections: [] }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "dashboard link on the form editor" do
    before { sign_in admin }

    let(:form) { create(:form, :standalone) }
    let(:event) { create(:event) }

    # Forms are shared across events, so the editor links back to the dashboard
    # of the event the admin came from, passed as event_id.
    context "when an event_id for a connected event is given" do
      before { create(:event_form, form: form, event: event) }

      it "links the dashboard button to that event on the questions editor" do
        get edit_form_path(form, event_id: event.id)
        expect(response.body).to include(dashboard_event_path(event))
      end

      it "links the dashboard button to that event on the sections editor" do
        get edit_sections_form_path(form, event_id: event.id)
        expect(response.body).to include(dashboard_event_path(event))
      end

      it "links Edit event to that event on the questions editor" do
        get edit_form_path(form, event_id: event.id)
        expect(response.body).to include(edit_event_path(event))
      end
    end

    it "ignores an event_id that is not connected to the form" do
      get edit_form_path(form, event_id: event.id)
      expect(response.body).not_to include(dashboard_event_path(event))
    end

    it "shows no dashboard link when the form spans multiple events and none is given" do
      create(:event_form, form: form, event: event)
      create(:event_form, form: form, event: create(:event))
      get edit_form_path(form)
      expect(response.body).not_to include("Dashboard")
    end

    it "offers only the standalone Preview link when no event is known" do
      get edit_form_path(form)
      expect(response.body).to include(">Preview<")
      expect(response.body).not_to include(">View<")
    end

    it "adds a View link to the live registration form when the event is known" do
      create(:event_form, form: form, event: event)
      get edit_form_path(form, event_id: event.id)
      expect(response.body).to include(">View<")
      expect(response.body).to include(new_event_public_registration_path(event))
      expect(response.body).to include(">Preview<")
    end
  end

  describe "GET /forms/:id/edit" do
    before { sign_in admin }

    it "shows form field editor" do
      form = FormBuilderService.new(name: "Test", sections: %i[person_identifier]).call
      get edit_form_path(form)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("First Name")
    end

    it "renders the collapsible per-field options controls" do
      form = FormBuilderService.new(name: "Test", sections: %i[person_identifier]).call
      get edit_form_path(form)

      expect(response.body).to include('data-controller="field-options answer-options"')
      expect(response.body).to include("field-options#toggle")
      expect(response.body).to include("Only ask once")
      expect(response.body).to include("Min words")
    end

    it "renders the editable answer options for a multiple-choice field" do
      form = FormBuilderService.new(name: "Test", sections: %i[person_contact_info]).call
      get edit_form_path(form)

      expect(response.body).to include('data-controller="field-options answer-options"')
      expect(response.body).to include("answer-options#toggle")
      # The radio field's seeded options are rendered as editable inputs
      expect(response.body).to include("[option_name]")
      expect(response.body).to include("+ Add option")
    end

    it "renders the answer-options scaffolding on every field so a field switched to a choice type can gain options" do
      # person_identifier seeds only free-form fields (no multiple-choice).
      # The answer-options UI must still be present (hidden) so the type
      # dropdown can reveal it client-side — otherwise a field changed to
      # "Single select radio" saves with no options and shows nothing on the
      # public form.
      form = FormBuilderService.new(name: "Test", sections: %i[person_identifier]).call
      expect(form.form_fields.none?(&:selectable?)).to be(true)

      get edit_form_path(form)

      expect(response.body).to include("answer-options#typeChanged")
      expect(response.body).to include('data-answer-options-target="list"')
      expect(response.body).to include("+ Add option")
    end

    it "shows payment-method options read-only (no editable inputs) without the admin override" do
      form = FormBuilderService.new(name: "Test", sections: %i[payment]).call
      payment_field = form.form_fields.find_by(field_identifier: "payment_method")
      expect(payment_field).to be_present

      get edit_form_path(form)

      # The options are still shown...
      FormBuilderService::PAYMENT_METHOD_OPTIONS.each do |option|
        expect(response.body).to include(option)
      end
      # ...but not as editable inputs, and they can't be added/removed.
      expect(response.body).not_to match(/payment_method.{0,600}\[option_name\]/m)
      expect(response.body).not_to match(/payment_method.{0,600}\+ Add option/m)
      # A note explains why they're locked.
      expect(response.body).to include("tied to system logic")
    end

    it "renders payment-method options as editable inputs with ?admin=true" do
      form = FormBuilderService.new(name: "Test", sections: %i[payment]).call

      get edit_form_path(form, admin: "true")

      expect(response.body).to include("[option_name]")
      expect(response.body).to include("+ Add option")
    end

    it "shows an option-source badge linking to the managed list for dynamic fields" do
      type = CategoryType.create!(name: "AgeRange", published: true)
      form = create(:form, :standalone)
      create(:form_field, form: form, answer_type: :single_select_radio,
             field_identifier: "primary_age_group", name: "Primary age group", status: :active)

      get edit_form_path(form)

      expect(response.body).to include("Options from")
      expect(response.body).to include("Age range categories")
      expect(response.body).to include(categories_path(category_type_id: type.id))
      # The per-field options editor is not offered for centrally-managed options
      expect(response.body).not_to match(/primary_age_group.{0,400}\+ Add option/m)
    end

    it "renders the expand/collapse all toggle" do
      form = FormBuilderService.new(name: "Test", sections: %i[person_identifier]).call
      get edit_form_path(form)

      expect(response.body).to include('data-controller="expand-all"')
      expect(response.body).to include("Expand all")
    end

    it "renders the form header section with a textarea for HTML" do
      form = create(:form, :standalone, header: "<strong>Welcome</strong>")
      get edit_form_path(form)

      expect(response.body).to include("Form header")
      expect(response.body).to include('name="form[header]"')
      # The raw HTML is escaped inside the textarea so admins edit the markup.
      expect(response.body).to include("&lt;strong&gt;Welcome&lt;/strong&gt;")
    end

    it "edits field and header names in textareas" do
      form = FormBuilderService.new(name: "Test", sections: %i[person_contact_info]).call
      get edit_form_path(form)

      expect(response.body).to include("<textarea")
    end

    it "renders an editable subtext field for a section header" do
      form = create(:form, :standalone)
      create(:form_field, form: form, answer_type: :group_header, name: "Contact info")

      get edit_form_path(form)

      expect(response.body).to include("[subtitle]")
    end

    it "warns that the Other option is hidden on a dropdown field" do
      form = create(:form, :standalone)
      field = create(:form_field, form: form, answer_type: :single_select_dropdown, name: "Favorite color")
      [ "Red", "Other" ].each_with_index do |name, i|
        option = create(:answer_option, name: name, position: i)
        create(:form_field_answer_option, form_field: field, answer_option: option)
      end

      get edit_form_path(form)

      expect(response.body).to include("The \"Other\" option is hidden on dropdown fields")
    end

    it "warns when a dynamic (category-backed) dropdown sources an Other option" do
      category_type = create(:category_type, name: "AgeRange")
      create(:category, :published, category_type: category_type, name: "3-5")
      create(:category, :published, category_type: category_type, name: "Other")
      form = create(:form, :standalone)
      create(:form_field, form: form, answer_type: :single_select_dropdown,
             field_identifier: "primary_age_group", name: "Primary Age Group(s) Served")

      get edit_form_path(form)

      expect(response.body).to include("The \"Other\" option is hidden on dropdown fields")
    end

    it "does not warn about Other on a dropdown field without an Other option" do
      form = create(:form, :standalone)
      field = create(:form_field, form: form, answer_type: :single_select_dropdown, name: "Favorite color")
      option = create(:answer_option, name: "Red", position: 0)
      create(:form_field_answer_option, form_field: field, answer_option: option)

      get edit_form_path(form)

      expect(response.body).not_to include("The \"Other\" option is hidden on dropdown fields")
    end
  end

  describe "GET /forms/:id (preview)" do
    before { sign_in admin }

    it "links Edit event to the sole connected event" do
      form = create(:form, :standalone)
      event = create(:event)
      create(:event_form, form: form, event: event)

      get form_path(form)

      expect(response.body).to include(edit_event_path(event))
    end

    it "shows no Edit event link when the form has no connected event" do
      form = create(:form, :standalone)
      get form_path(form)
      expect(response.body).not_to include("Edit event")
    end

    it "shows no Edit event link when the form spans multiple events and none is given" do
      form = create(:form, :standalone)
      create(:event_form, form: form, event: create(:event))
      create(:event_form, form: form, event: create(:event))
      get form_path(form)
      expect(response.body).not_to include("Edit event")
    end

    it "links Edit event to the event given by param even when the form has several" do
      form = create(:form, :standalone)
      event = create(:event)
      create(:event_form, form: form, event: event)
      create(:event_form, form: form, event: create(:event))
      get form_path(form, event_id: event.id)
      expect(response.body).to include(edit_event_path(event))
    end

    it "renders header and field-label HTML unescaped" do
      form = create(:form, :standalone)
      create(:form_field, form: form, answer_type: :group_header, name: "<strong>Section</strong>")
      create(:form_field, form: form, answer_type: :free_form_input_one_line, name: "<em>Your name</em>", required: false)

      get form_path(form)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("<strong>Section</strong>")
      expect(response.body).to include("<em>Your name</em>")
    end

    it "warns that the Other option is hidden on a dropdown field" do
      form = create(:form, :standalone)
      field = create(:form_field, form: form, answer_type: :single_select_dropdown, name: "Favorite color")
      [ "Red", "Other" ].each_with_index do |name, i|
        option = create(:answer_option, name: name, position: i)
        create(:form_field_answer_option, form_field: field, answer_option: option)
      end

      get form_path(form)

      expect(response.body).to include("The \"Other\" option is hidden on dropdown fields")
    end

    it "renders a section header's subtext under the heading" do
      form = create(:form, :standalone)
      create(:form_field, form: form, answer_type: :group_header, name: "Contact info", subtitle: "Tell us how to reach you")

      get form_path(form)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Tell us how to reach you")
    end

    it "renders a field's subtitle as sanitized HTML under the label" do
      form = create(:form, :standalone)
      create(:form_field, form: form, name: "Email", subtitle: %(We'll <strong>never</strong> share it))

      get form_path(form)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("We'll <strong>never</strong> share it")
    end

    it "renders a field's hint text as sanitized HTML below the input" do
      form = create(:form, :standalone)
      create(:form_field, form: form, name: "Phone", hint_text: %(Include your <em>area code</em>))

      get form_path(form)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Include your <em>area code</em>")
    end

    it "renders the form header HTML under the title" do
      form = create(:form, :standalone, header: %(<strong>Welcome</strong> — <a href="https://awbw.org">learn more</a>))

      get form_path(form)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("<strong>Welcome</strong>")
      expect(response.body).to include(%(<a href="https://awbw.org">learn more</a>))
    end

    it "labels the preview header with the form role and a Preview badge" do
      form = create(:form, :standalone, name: "Summer Camp", role: "registration")

      get form_path(form)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Summer Camp")
      expect(response.body).to include("Registration form")
      expect(response.body).to include("Preview")
    end

    it "links a dynamic field's options to the managed list" do
      type = CategoryType.create!(name: "AgeRange", published: true)
      form = create(:form, :standalone)
      create(:form_field, form: form, answer_type: :single_select_radio,
             field_identifier: "primary_age_group", name: "Primary age group", status: :active)

      get form_path(form)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Options from")
      expect(response.body).to include("Age range categories")
      expect(response.body).to include(categories_path(category_type_id: type.id))
    end
  end

  describe "PATCH /forms/:id" do
    before { sign_in admin }

    it "updates form name" do
      form = create(:form, :standalone, name: "Old Name")
      patch form_path(form), params: { form: { name: "New Name" } }
      expect(form.reload.name).to eq("New Name")
      expect(response).to redirect_to(edit_form_path(form))
    end

    it "updates the form header HTML" do
      form = create(:form, :standalone)
      patch form_path(form), params: { form: { header: "<strong>Read carefully</strong>" } }
      expect(form.reload.header).to eq("<strong>Read carefully</strong>")
      expect(response).to redirect_to(edit_form_path(form))
    end

    it "saves the subtext for a section header" do
      form = create(:form, :standalone)
      header = create(:form_field, form: form, answer_type: :group_header, name: "Contact info")
      patch form_path(form), params: {
        form: { form_fields_attributes: { "0" => { id: header.id, subtitle: "Tell us how to reach you" } } }
      }
      expect(header.reload.subtitle).to eq("Tell us how to reach you")
      expect(response).to redirect_to(edit_form_path(form))
    end

    it "saves the hint text for a field" do
      form = create(:form, :standalone)
      field = create(:form_field, form: form, name: "Phone")
      patch form_path(form), params: {
        form: { form_fields_attributes: { "0" => { id: field.id, hint_text: "Include your area code" } } }
      }
      expect(field.reload.hint_text).to eq("Include your area code")
      expect(response).to redirect_to(edit_form_path(form))
    end

    it "saves the field_identifier for a field" do
      form = create(:form, :standalone)
      field = create(:form_field, form: form, name: "Pick a payment method")
      patch form_path(form), params: {
        form: { form_fields_attributes: { "0" => { id: field.id, field_identifier: "payment_method" } } }
      }
      expect(field.reload.field_identifier).to eq("payment_method")
      expect(response).to redirect_to(edit_form_path(form))
    end

    it "updates hide_answered flags" do
      form = create(:form, :standalone)
      patch form_path(form), params: {
        form: { hide_answered_person_questions: true, hide_answered_form_questions: true }
      }
      form.reload
      expect(form.hide_answered_person_questions).to be true
      expect(form.hide_answered_form_questions).to be true
    end

    it "appends a newly added field to the bottom of the list, not the top" do
      form = create(:form, :standalone)
      first = create(:form_field, form: form, name: "First", position: 1)
      second = create(:form_field, form: form, name: "Second", position: 2)

      patch form_path(form), params: {
        form: { form_fields_attributes: { "0" => { name: "Brand new", answer_type: "free_form_input_one_line" } } }
      }
      expect(response).to redirect_to(edit_form_path(form))

      new_field = form.form_fields.find_by(name: "Brand new")
      expect(new_field.position).to be > second.position
      ordered = form.form_fields.reorder(position: :asc).pluck(:name)
      expect(ordered).to eq([ first.name, second.name, "Brand new" ])
    end

    it "saves a long, multi-sentence question name" do
      form = create(:form, :standalone)
      long_name = "AWBW workshops are used in a variety of ways. " * 8
      patch form_path(form), params: {
        form: { form_fields_attributes: { "0" => { name: long_name, answer_type: "free_form_input_paragraph" } } }
      }
      expect(response).to redirect_to(edit_form_path(form))
      expect(form.form_fields.where(name: long_name)).to exist
    end

    it "renders a validation error instead of 500 when a name is too long" do
      form = create(:form, :standalone)
      patch form_path(form), params: {
        form: { form_fields_attributes: { "0" => { name: "x" * 1001, answer_type: "free_form_input_one_line" } } }
      }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("too long")
    end

    it "renames a multiple-choice field's answer option without renaming the shared option" do
      form = FormBuilderService.new(name: "Test", sections: %i[marketing]).call
      field = form.form_fields.find_by(field_identifier: "interested_in_more")
      join = field.form_field_answer_options.joins(:answer_option).find_by(answer_options: { name: "Yes" })

      patch form_path(form), params: {
        form: { form_fields_attributes: { "0" => {
          id: field.id, name: field.name, answer_type: field.answer_type,
          form_field_answer_options_attributes: { "0" => { id: join.id, option_name: "Absolutely" } }
        } } }
      }

      expect(response).to redirect_to(edit_form_path(form))
      expect(join.reload.answer_option.name).to eq("Absolutely")
      expect(field.reload.answer_options.map(&:name)).to include("Absolutely")
    end

    it "adds a new answer option to a multiple-choice field" do
      form = FormBuilderService.new(name: "Test", sections: %i[marketing]).call
      field = form.form_fields.find_by(field_identifier: "interested_in_more")

      expect {
        patch form_path(form), params: {
          form: { form_fields_attributes: { "0" => {
            id: field.id, name: field.name, answer_type: field.answer_type,
            form_field_answer_options_attributes: { "0" => { option_name: "Maybe" } }
          } } }
        }
      }.to change { field.reload.form_field_answer_options.count }.by(1)

      expect(field.answer_options.map(&:name)).to include("Maybe")
    end

    it "ignores a blank new answer option" do
      form = FormBuilderService.new(name: "Test", sections: %i[marketing]).call
      field = form.form_fields.find_by(field_identifier: "interested_in_more")

      expect {
        patch form_path(form), params: {
          form: { form_fields_attributes: { "0" => {
            id: field.id, name: field.name, answer_type: field.answer_type,
            form_field_answer_options_attributes: { "0" => { option_name: "" } }
          } } }
        }
      }.not_to change { field.reload.form_field_answer_options.count }
    end

    it "removes an answer option from a multiple-choice field" do
      form = FormBuilderService.new(name: "Test", sections: %i[marketing]).call
      field = form.form_fields.find_by(field_identifier: "interested_in_more")
      join = field.form_field_answer_options.joins(:answer_option).find_by(answer_options: { name: "No" })

      expect {
        patch form_path(form), params: {
          form: { form_fields_attributes: { "0" => {
            id: field.id, name: field.name, answer_type: field.answer_type,
            form_field_answer_options_attributes: { "0" => { id: join.id, option_name: "No", _destroy: "1" } }
          } } }
        }
      }.to change { field.reload.form_field_answer_options.count }.by(-1)

      expect(field.answer_options.map(&:name)).not_to include("No")
    end

    it "saves the per-field width, minimum word count, and maximum character count" do
      form = create(:form, :standalone)
      patch form_path(form), params: {
        form: { form_fields_attributes: { "0" => {
          name: "Essay", answer_type: "free_form_input_paragraph", width: "half", min_words: "25", max_characters: "500"
        } } }
      }
      expect(response).to redirect_to(edit_form_path(form))
      field = form.form_fields.find_by(name: "Essay")
      expect(field.width).to eq("half")
      expect(field.min_words).to eq(25)
      expect(field.max_characters).to eq(500)
    end
  end

  describe "DELETE /forms/:id" do
    before { sign_in admin }

    it "destroys the form" do
      form = create(:form, :standalone, name: "Doomed")
      expect { delete form_path(form) }.to change(Form, :count).by(-1)
      expect(response).to redirect_to(forms_path)
    end
  end

  describe "GET /forms/:id" do
    before { sign_in admin }

    it "shows form preview" do
      form = FormBuilderService.new(name: "Preview", sections: %i[person_identifier]).call
      get form_path(form)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("First Name")
    end

    it "shows every field including conditional ones, without applying the conditional logic" do
      form = create(:form, :standalone)
      create(:form_field, form: form, name: "Always Field", visibility: :always_ask)
      create(:form_field, form: form, name: "Hidden When Logged In", visibility: :logged_out_only)

      get form_path(form)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Always Field")
      expect(response.body).to include("Hidden When Logged In")
    end

    it "highlights fields that are not always asked" do
      form = create(:form, :standalone)
      create(:form_field, form: form, name: "On File Field", visibility: :answers_on_file)

      get form_path(form)

      expect(response.body).to include("Answers on file")
    end
  end

  describe "GET /forms/:id/edit_sections" do
    before { sign_in admin }

    it "shows section checkboxes for existing form" do
      form = FormBuilderService.new(name: "Editable", sections: %i[person_identifier]).call
      get edit_sections_form_path(form)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Person identifier")
    end

    it "lists an included section's actual fields behind an expandable toggle" do
      form = FormBuilderService.new(name: "Editable", sections: %i[person_identifier]).call
      get edit_sections_form_path(form)
      expect(response.body).to include("First Name")
      expect(response.body).to include('data-controller="form-section-toggle expandable-card"')
    end

    it "shows custom sections with a custom indicator" do
      form = FormBuilderService.new(name: "Editable", sections: %i[person_identifier]).call
      form.form_fields.create!(name: "My Special Section", answer_type: :group_header,
                               status: :active, position: 100, required: false)

      get edit_sections_form_path(form)

      expect(response.body).to include("My Special Section")
      expect(response.body).to include("Custom sections")
    end
  end

  describe "PATCH /forms/:id/update_sections" do
    before { sign_in admin }

    it "adds new sections to existing form" do
      form = FormBuilderService.new(name: "Growing", sections: %i[person_identifier]).call
      initial_count = form.form_fields.count

      patch update_sections_form_path(form), params: {
        sections: %w[person_identifier consent]
      }

      form.reload
      expect(form.sections).to include("consent")
      expect(form.form_fields.count).to be > initial_count
      expect(response).to redirect_to(edit_form_path(form))
    end

    it "removes sections from existing form" do
      form = FormBuilderService.new(name: "Shrinking", sections: %i[person_identifier consent]).call
      patch update_sections_form_path(form), params: {
        sections: %w[person_identifier]
      }

      form.reload
      expect(form.sections).not_to include("consent")
      expect(form.form_fields.where(section: "consent")).to be_empty
    end

    it "rejects empty sections" do
      form = FormBuilderService.new(name: "Protected", sections: %i[person_identifier]).call
      patch update_sections_form_path(form), params: { sections: [] }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "leaves the form untouched when the section set is unchanged" do
      form = FormBuilderService.new(name: "Unchanged", sections: %i[person_identifier consent]).call
      original_ids = form.form_fields.pluck(:id).sort
      expect(FormBuilderService).not_to receive(:update_sections!)

      patch update_sections_form_path(form), params: {
        sections: %w[consent person_identifier]
      }

      form.reload
      expect(form.form_fields.pluck(:id).sort).to eq(original_ids)
      expect(response).to redirect_to(edit_form_path(form))
    end

    it "removes a custom section the user unchecked" do
      form = FormBuilderService.new(name: "Custom", sections: %i[person_identifier]).call
      header = form.form_fields.create!(name: "My Special Section", answer_type: :group_header,
                                        status: :active, position: 100, required: false)

      patch update_sections_form_path(form), params: {
        sections: %w[person_identifier],
        custom_sections: [ header.id ],
        kept_custom_sections: []
      }

      expect(FormField.where(id: header.id)).to be_empty
      expect(response).to redirect_to(edit_form_path(form))
    end

    it "keeps a custom section that stays checked" do
      form = FormBuilderService.new(name: "Custom", sections: %i[person_identifier]).call
      header = form.form_fields.create!(name: "My Special Section", answer_type: :group_header,
                                        status: :active, position: 100, required: false)

      patch update_sections_form_path(form), params: {
        sections: %w[person_identifier],
        custom_sections: [ header.id ],
        kept_custom_sections: [ header.id ]
      }

      expect(FormField.where(id: header.id)).to exist
    end
  end

  describe "PUT /forms/:id/reorder_fields" do
    before { sign_in admin }

    it "reorders fields" do
      form = FormBuilderService.new(name: "Reorder", sections: %i[person_identifier]).call
      fields = form.form_fields.reorder(position: :asc)
      new_positions = fields.map.with_index { |f, i| { id: f.id, position: fields.size - i } }

      put reorder_fields_form_path(form),
        params: { positions: new_positions }.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
    end
  end
end
