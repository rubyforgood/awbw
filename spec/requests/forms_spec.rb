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
  end
end
