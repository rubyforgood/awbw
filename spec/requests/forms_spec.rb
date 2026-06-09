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
  end

  describe "PATCH /forms/:id" do
    before { sign_in admin }

    it "updates form name" do
      form = create(:form, :standalone, name: "Old Name")
      patch form_path(form), params: { form: { name: "New Name" } }
      expect(form.reload.name).to eq("New Name")
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
  end

  describe "GET /forms/:id/edit_sections" do
    before { sign_in admin }

    it "shows section checkboxes for existing form" do
      form = FormBuilderService.new(name: "Editable", sections: %i[person_identifier]).call
      get edit_sections_form_path(form)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Person identifier")
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
