require "rails_helper"

RSpec.describe "FormSubmissions", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:submission) { create(:form_submission) }

  describe "GET /form_submissions" do
    context "as an admin" do
      before { sign_in admin }

      # The rows load lazily inside the results Turbo frame.
      let(:frame_headers) { { "Turbo-Frame" => "form_submissions_results" } }

      it "renders the filterable index shell" do
        get form_submissions_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Form submissions")
      end

      it "lists a person's submissions and links each to its detail page" do
        person = create(:person, first_name: "Priya", last_name: "Patel")
        other = create(:person)
        mine = create(:form_submission, person: person)
        theirs = create(:form_submission, person: other)

        get form_submissions_path(person_id: person.id), headers: frame_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(form_submission_path(mine))
        expect(response.body).not_to include(form_submission_path(theirs))
      end

      it "filters by form" do
        wanted = create(:form, name: "Volunteer interest")
        other = create(:form, name: "Something else")
        mine = create(:form_submission, form: wanted)
        theirs = create(:form_submission, form: other)

        get form_submissions_path(form_id: wanted.id), headers: frame_headers

        expect(response.body).to include(form_submission_path(mine))
        expect(response.body).not_to include(form_submission_path(theirs))
      end

      it "breaks the View link out of the results frame" do
        create(:form_submission)
        get form_submissions_path, headers: frame_headers
        expect(response.body).to include('data-turbo-frame="_top"')
      end

      it "shows a Forms eyebrow anchored to the form when arriving from the forms index" do
        form = create(:form, name: "Volunteer interest")
        get form_submissions_path(form_id: form.id, return_to: "forms")

        expect(response.body).to include(CGI.escapeHTML(forms_path(anchor: "form_#{form.id}")))
      end

      it "each View link carries a return_to back to the person's index" do
        person = create(:person)
        submission = create(:form_submission, person: person)

        get form_submissions_path(person_id: person.id), headers: frame_headers

        expect(response.body).to include(
          CGI.escapeHTML(form_submission_path(submission, return_to: "form_submissions", person_id: person.id))
        )
      end
    end

    context "as a non-admin" do
      before { sign_in create(:user) }

      it "redirects away" do
        get form_submissions_path

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /form_submissions/:id" do
    context "as an admin" do
      before { sign_in admin }

      it "renders the submission" do
        field = create(:form_field, form: submission.form, name: "Organization")
        create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "AWBW")

        get form_submission_path(submission)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Organization")
        expect(response.body).to include("AWBW")
      end

      it "shows a back link to the form submissions index when arriving from it" do
        get form_submission_path(submission, return_to: "form_submissions", person_id: submission.person_id)

        expect(response.body).to include(form_submissions_path(person_id: submission.person_id))
        expect(response.body).to include("Back to form submissions")
      end

      it "resolves the sector/age-group ids stored behind the professional fields to names" do
        sector = create(:sector, :published, name: "Mental Health")
        sector_field = create(:form_field, form: submission.form, name: "Additional sectors",
                              answer_type: :multi_select_checkbox, field_identifier: "additional_sectors")
        create(:form_answer, form_submission: submission, form_field: sector_field,
               submitted_answer: "#{sector.id}, Other: Equine therapy")

        get form_submission_path(submission)

        # The stored ids resolve to names; the free-text "Other:" answer passes through.
        expect(response.body).to include("Mental Health, Other: Equine therapy")
        expect(response.body).not_to match(/>\s*#{sector.id},/)
      end
    end

    context "when arriving from the bulk payments index" do
      before { sign_in admin }

      let(:event) { create(:event) }

      before do
        EventForm.create!(event: event, form: submission.form, role: "bulk_payment")
        submission.update!(role: "bulk_payment")
      end

      it "points the back link at bulk payments" do
        get form_submission_path(submission, return_to: "bulk_payments")

        expect(response.body).to include(bulk_payments_event_path(event))
        expect(response.body).to include("Back to bulk payments")
      end

      it "points the back link at the event without the return_to context" do
        get form_submission_path(submission)

        expect(response.body).to include("Back to event")
        expect(response.body).not_to include("Back to bulk payments")
      end
    end

    context "as a non-admin" do
      before { sign_in create(:user) }

      it "redirects away" do
        get form_submission_path(submission)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
