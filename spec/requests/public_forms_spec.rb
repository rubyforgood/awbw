require "rails_helper"

RSpec.describe "PublicForms", type: :request do
  let(:form) { create(:form, name: "Volunteer interest", slug: "volunteer-interest", published: true) }

  let!(:first_name_field) { create(:form_field, form: form, name: "First name", field_identifier: "first_name", required: true) }
  let!(:last_name_field)  { create(:form_field, form: form, name: "Last name", field_identifier: "last_name", required: true) }
  let!(:email_field)      { create(:form_field, form: form, name: "Email", field_identifier: "primary_email", required: true) }

  def submission_params(first: "Sam", last: "Rivera", email: "sam@example.com")
    {
      public_registration: {
        Honeypot::FIELD_NAME => "",
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
      params = submission_params.deep_merge(public_registration: { Honeypot::FIELD_NAME => "http://spam.example" })

      expect { post public_form_path(form.slug), params: params }
        .not_to change(FormSubmission, :count)

      expect(response).to redirect_to(public_form_path(form.slug))
    end
  end

  describe "anonymous submissions" do
    before { [ first_name_field, last_name_field, email_field ].each { |field| field.update!(required: false) } }

    it "tells respondents the form can be submitted anonymously" do
      get public_form_path(form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("submit this form anonymously")
    end

    it "records a person-less submission when identity is left blank" do
      expect { post public_form_path(form.slug), params: submission_params(first: "", last: "", email: "") }
        .to change(FormSubmission, :count).by(1)
        .and change(Person, :count).by(0)

      expect(response).to redirect_to(thank_you_public_form_path(form.slug))
      expect(FormSubmission.last.person).to be_nil
    end

    it "still builds a person when the respondent fills in name and email" do
      expect { post public_form_path(form.slug), params: submission_params }
        .to change(Person, :count).by(1)
    end
  end

  describe "agreement-role forms always require identity" do
    let(:form) { create(:form, name: "On-demand agreement", slug: "collab", published: true, role: "registration") }

    before { [ first_name_field, last_name_field, email_field ].each { |field| field.update!(required: false) } }

    it "does not offer anonymous submission and blocks a blank-identity submission" do
      get public_form_path(form.slug)
      expect(response.body).not_to include("submit this form anonymously")

      expect { post public_form_path(form.slug), params: submission_params(first: "", last: "", email: "") }
        .not_to change(FormSubmission, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "slider fields" do
    let!(:slider_field) do
      create(:form_field, form: form, name: "What percentage are one-on-one?", answer_type: :slider, required: false)
    end

    def slider_params(value)
      params = submission_params
      params[:public_registration][:form_fields][slider_field.id.to_s] = value
      params
    end

    it "renders a range input for a slider question" do
      get public_form_path(form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="slider"')
      expect(response.body).to include('type="range"')
    end

    it "persists a valid slider value" do
      post public_form_path(form.slug), params: slider_params("40")

      answer = FormAnswer.find_by(form_field: slider_field)
      expect(answer.submitted_answer).to eq("40")
    end

    it "rejects an out-of-range slider value" do
      expect { post public_form_path(form.slug), params: slider_params("150") }
        .not_to change(FormSubmission, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("between 0 and 100")
    end
  end

  # The end-to-end wiring: the tag writes are buffered mid-request and stamped
  # with the submission id when the controller flushes, so the admin audit page
  # can find them. A service-level spec can't reach the flush.
  describe "the submission's audit trail" do
    BROWSER_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".freeze

    let!(:health) { create(:sector, :published, name: "Healthcare") }
    let!(:housing) { create(:sector, :published, name: "Housing") }
    let!(:primary_field) { create(:form_field, form: form, name: "Primary sector", field_identifier: "primary_sector") }
    let!(:additional_field) { create(:form_field, form: form, name: "Additional sectors", field_identifier: "additional_sectors") }
    let!(:person) { create(:person, user: nil, first_name: "Sam", last_name: "Rivera", email: "sam@example.com") }

    it "records the sectors a re-submission dropped and demoted" do
      person.sectorable_items.create!(sector: housing, is_primary: true)

      params = submission_params
      params[:public_registration][:form_fields][primary_field.id.to_s] = health.id.to_s
      params[:public_registration][:form_fields][additional_field.id.to_s] = [ health.id.to_s ]
      # Ahoy drops bot traffic, and Rack::Test's default agent reads as one — so
      # without a browser agent nothing is tracked and the assertion passes vacuously.
      post public_form_path(form.slug), params: params, headers: { "HTTP_USER_AGENT" => BROWSER_USER_AGENT }

      expect(response).to have_http_status(:redirect)
      changes = FormSubmissionChanges.new(FormSubmission.last).groups
        .flat_map(&:changes).map { |change| [ change.outcome, change.value ] }
      expect(changes).to include([ "Removed", "Housing (primary)" ], [ "Added", "Healthcare (primary)" ])
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
