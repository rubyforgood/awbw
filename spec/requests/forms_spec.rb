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
    end

    context "as regular user" do
      before { sign_in user }

      it "denies access" do
        get forms_path
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
      expect(response).to redirect_to(edit_form_path(form))
    end

    it "rejects when no sections selected" do
      post forms_path, params: { name: "Empty", sections: [] }
      expect(response).to have_http_status(:unprocessable_content)
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

      expect(response.body).to include('data-controller="field-options"')
      expect(response.body).to include("field-options#toggle")
      expect(response.body).to include("Only ask once")
      expect(response.body).to include("Min words")
    end

    it "renders the editable answer options for a multiple-choice field" do
      form = FormBuilderService.new(name: "Test", sections: %i[person_contact_info]).call
      get edit_form_path(form)

      expect(response.body).to include('data-controller="answer-options"')
      expect(response.body).to include("answer-options#toggle")
      # The radio field's seeded options are rendered as editable inputs
      expect(response.body).to include("[option_name]")
      expect(response.body).to include("+ Add option")
    end

    it "renders the expand/collapse all toggle" do
      form = FormBuilderService.new(name: "Test", sections: %i[person_identifier]).call
      get edit_form_path(form)

      expect(response.body).to include('data-controller="expand-all"')
      expect(response.body).to include("Expand all")
    end

    it "renders the form header section with a rich-text editor" do
      form = create(:form, :standalone, rhino_header: "<strong>Welcome</strong>")
      get edit_form_path(form)

      expect(response.body).to include("Form header")
      expect(response.body).to include('name="form[rhino_header]"')
      expect(response.body).to include("custom-rhino-editor")
    end

    it "edits field and header names in textareas" do
      form = FormBuilderService.new(name: "Test", sections: %i[person_contact_info]).call
      get edit_form_path(form)

      expect(response.body).to include("<textarea")
    end
  end

  describe "GET /forms/:id (preview)" do
    before { sign_in admin }

    it "renders header and field-label HTML unescaped" do
      form = create(:form, :standalone)
      create(:form_field, form: form, answer_type: :group_header, name: "<strong>Section</strong>")
      create(:form_field, form: form, answer_type: :free_form_input_one_line, name: "<em>Your name</em>", required: false)

      get form_path(form)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("<strong>Section</strong>")
      expect(response.body).to include("<em>Your name</em>")
    end

    it "renders the form header rich text under the title" do
      form = create(:form, :standalone, rhino_header: %(<strong>Welcome</strong> — <a href="https://awbw.org">learn more</a>))

      get form_path(form)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("<strong>Welcome</strong>")
      expect(response.body).to include("learn more")
      expect(response.body).to include("https://awbw.org")
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

    it "updates the form header rich text" do
      form = create(:form, :standalone)
      patch form_path(form), params: { form: { rhino_header: "<strong>Read carefully</strong>" } }
      expect(form.reload.rhino_header.to_plain_text).to eq("Read carefully")
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
