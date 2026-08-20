require "rails_helper"

RSpec.describe "PublicForms", type: :request do
  let(:form) { create(:form, name: "Volunteer interest", slug: "volunteer-interest", published: true) }

  let!(:first_name_field) { create(:form_field, form: form, name: "First name", field_identifier: "first_name", required: true) }
  let!(:last_name_field)  { create(:form_field, form: form, name: "Last name", field_identifier: "last_name", required: true) }
  let!(:email_field)      { create(:form_field, form: form, name: "Email", field_identifier: "primary_email", required: true) }

  def submission_params(first: "Sam", last: "Rivera", email: "sam@example.com")
    {
      public_registration: {
        form_fields: {
          first_name_field.id.to_s => first,
          last_name_field.id.to_s => last,
          email_field.id.to_s => email
        }
      }
    }
  end

  describe "GET /f/:slug" do
    it "renders the form for anyone, no account needed" do
      get public_form_path(form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Volunteer interest")
      expect(response.body).to include("First name")
    end

    it "404s an unpublished form" do
      form.update_column(:published, false)
      get public_form_path(form.slug)
      expect(response).to have_http_status(:not_found)
    end

    it "404s an event-owned form even if published" do
      owned = create(:form, :with_owner, slug: "internal")
      owned.update_column(:published, true)
      get public_form_path(owned.slug)
      expect(response).to have_http_status(:not_found)
    end

    it "404s a form connected to an event even if published" do
      EventForm.create!(form: form, event: create(:event), role: "registration")
      get public_form_path(form.slug)
      expect(response).to have_http_status(:not_found)
    end

    it "404s an unknown slug" do
      get public_form_path("nope")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /f/:slug" do
    it "records a submission and redirects to the thank-you page" do
      expect { post public_form_path(form.slug), params: submission_params }
        .to change(FormSubmission, :count).by(1)
        .and change(Person, :count).by(1)

      expect(response).to redirect_to(thank_you_public_form_path(form.slug))
    end

    it "re-renders with errors when a required field is missing" do
      expect { post public_form_path(form.slug), params: submission_params(email: "") }
        .not_to change(FormSubmission, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "silently bounces a honeypot-tripping bot without recording anything" do
      params = submission_params.deep_merge(public_registration: { website_url: "http://spam.example" })

      expect { post public_form_path(form.slug), params: params }
        .not_to change(FormSubmission, :count)

      expect(response).to redirect_to(public_form_path(form.slug))
    end
  end

  describe "GET /f/:slug/thank-you" do
    it "renders a confirmation" do
      get thank_you_public_form_path(form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Thank you")
    end
  end
end
