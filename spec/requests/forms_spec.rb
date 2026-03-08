require "rails_helper"

RSpec.describe "/forms", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let!(:form) { create(:form, :standalone, name: "Test Registration Form") }

  describe "GET /index" do
    context "as an admin" do
      before { sign_in admin }

      it "renders successfully" do
        get forms_path
        expect(response).to be_successful
      end

      it "shows forms in the body" do
        get forms_path
        expect(response.body).to include("Test Registration Form")
      end
    end

    context "as a non-admin user" do
      before { sign_in regular_user }

      it "redirects with unauthorized" do
        get forms_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        get forms_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /show" do
    before { sign_in admin }

    it "renders a successful response" do
      get form_url(form)
      expect(response).to be_successful
      expect(response.body).to include("Test Registration Form")
    end
  end

  describe "GET /new" do
    before { sign_in admin }

    it "renders the builder selection page" do
      get new_form_url
      expect(response).to be_successful
      expect(response.body).to include("Short Event Registration")
      expect(response.body).to include("Extended Event Registration")
      expect(response.body).to include("Scholarship Application")
      expect(response.body).to include("Generic Form")
    end
  end

  describe "GET /edit" do
    before { sign_in admin }

    it "renders a successful response" do
      get edit_form_url(form)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    before { sign_in admin }

    it "creates a form with the short registration builder" do
      expect {
        post forms_url, params: { builder_type: "short_registration" }
      }.to change(Form, :count).by(1)

      new_form = Form.last
      expect(new_form.name).to eq("Short Event Registration")
      expect(new_form.form_fields).to be_present
      expect(response).to redirect_to(edit_form_url(new_form))
    end

    it "creates a form with the extended registration builder" do
      expect {
        post forms_url, params: { builder_type: "extended_registration" }
      }.to change(Form, :count).by(1)

      new_form = Form.last
      expect(new_form.name).to eq("Extended Event Registration")
      expect(response).to redirect_to(edit_form_url(new_form))
    end

    it "creates a form with the scholarship builder" do
      expect {
        post forms_url, params: { builder_type: "scholarship_application" }
      }.to change(Form, :count).by(1)

      new_form = Form.last
      expect(new_form.name).to eq("Scholarship Application")
      expect(new_form.scholarship_application?).to be true
      expect(response).to redirect_to(edit_form_url(new_form))
    end

    it "creates a generic form with a custom name" do
      expect {
        post forms_url, params: { builder_type: "generic", form_name: "My Custom Form" }
      }.to change(Form, :count).by(1)

      new_form = Form.last
      expect(new_form.name).to eq("My Custom Form")
      expect(new_form.form_fields).to be_empty
      expect(response).to redirect_to(edit_form_url(new_form))
    end

    it "creates a generic form with default name when blank" do
      post forms_url, params: { builder_type: "generic", form_name: "" }
      expect(Form.last.name).to eq("New Form")
    end
  end

  describe "PATCH /update" do
    before { sign_in admin }

    it "updates the form name" do
      patch form_url(form), params: { form: { name: "Updated Form Name" } }
      form.reload
      expect(form.name).to eq("Updated Form Name")
      expect(response).to redirect_to(form_url(form))
    end

    it "updates a nested field question label" do
      field = create(:form_field, form: form, question: "Original Question")
      patch form_url(form), params: {
        form: {
          form_fields_attributes: {
            "0" => { id: field.id, question: "Updated Question" }
          }
        }
      }
      field.reload
      expect(field.question).to eq("Updated Question")
    end

    it "removes a field via _destroy" do
      field = create(:form_field, form: form)
      expect {
        patch form_url(form), params: {
          form: {
            form_fields_attributes: {
              "0" => { id: field.id, _destroy: "1" }
            }
          }
        }
      }.to change(FormField, :count).by(-1)
    end
  end

  describe "DELETE /destroy" do
    before { sign_in admin }

    it "destroys the requested form" do
      form_to_delete = create(:form, :standalone)
      expect {
        delete form_url(form_to_delete)
      }.to change(Form, :count).by(-1)
    end

    it "redirects to the forms list" do
      delete form_url(form)
      expect(response).to redirect_to(forms_url)
    end
  end

  describe "POST /add_questions" do
    before { sign_in admin }

    it "clones questions from another form" do
      source_form = create(:form, :standalone, name: "Source Form")
      source_field = create(:form_field, form: source_form, question: "Source Q", field_key: "source_q")

      expect {
        post add_questions_form_url(form), params: { source_field_ids: [ source_field.id ] }
      }.to change(form.form_fields, :count).by(1)

      cloned = form.form_fields.reorder(position: :asc).last
      expect(cloned.question).to eq("Source Q")
      expect(cloned.field_key).to eq("source_q")
      expect(response).to redirect_to(edit_form_url(form))
    end
  end
end
