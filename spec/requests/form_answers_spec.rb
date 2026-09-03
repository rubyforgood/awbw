require "rails_helper"

RSpec.describe "FormAnswers", type: :request do
  let(:admin) { create(:user, :admin) }

  describe "GET /form_answers" do
    context "as an admin" do
      before { sign_in admin }

      # The rows load lazily inside the results Turbo frame.
      let(:frame_headers) { { "Turbo-Frame" => "form_answers_results" } }

      it "renders the filterable index shell" do
        get form_answers_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Answers")
      end

      it "searches by answer text" do
        wanted = create(:form_answer, submitted_answer: "Loves painting murals")
        other = create(:form_answer, submitted_answer: "Prefers sculpture")

        get form_answers_path(q: "murals"), headers: frame_headers

        expect(response.body).to include("Loves painting murals")
        expect(response.body).not_to include("Prefers sculpture")
      end

      it "searches by question text" do
        form = create(:form)
        wanted = create(:form_field, form: form, name: "What is your favorite medium?")
        other = create(:form_field, form: form, name: "How did you hear about us?")
        create(:form_answer, submitted_answer: "medium-answer", form_field: wanted)
        create(:form_answer, submitted_answer: "referral-answer", form_field: other)

        get form_answers_path(question: "favorite medium"), headers: frame_headers

        expect(response.body).to include("medium-answer")
        expect(response.body).not_to include("referral-answer")
      end

      it "filters by form" do
        wanted_form = create(:form, name: "Volunteer interest")
        other_form = create(:form, name: "Something else")
        mine = create(:form_answer, submitted_answer: "keep-me",
                      form_submission: create(:form_submission, form: wanted_form))
        create(:form_answer, submitted_answer: "drop-me",
               form_submission: create(:form_submission, form: other_form))

        get form_answers_path(form_id: wanted_form.id), headers: frame_headers

        expect(response.body).to include("keep-me")
        expect(response.body).not_to include("drop-me")
      end

      it "filters by event" do
        wanted_event = create(:event)
        other_event = create(:event)
        create(:form_answer, submitted_answer: "at-my-event",
               form_submission: create(:form_submission, event: wanted_event))
        create(:form_answer, submitted_answer: "at-other-event",
               form_submission: create(:form_submission, event: other_event))

        get form_answers_path(event_id: wanted_event.id), headers: frame_headers

        expect(response.body).to include("at-my-event")
        expect(response.body).not_to include("at-other-event")
      end

      it "filters by organization" do
        org = create(:organization)
        linked = create(:form_submission)
        linked.link_organization!(org.id)
        create(:form_answer, submitted_answer: "for-this-org", form_submission: linked)
        create(:form_answer, submitted_answer: "for-other-org", form_submission: create(:form_submission))

        get form_answers_path(organization_id: org.id), headers: frame_headers

        expect(response.body).to include("for-this-org")
        expect(response.body).not_to include("for-other-org")
      end

      it "filters by person" do
        priya = create(:person, first_name: "Priya", last_name: "Patel")
        other = create(:person, first_name: "Sam", last_name: "Jones")
        create(:form_answer, submitted_answer: "priya-answer",
               form_submission: create(:form_submission, person: priya))
        create(:form_answer, submitted_answer: "sam-answer",
               form_submission: create(:form_submission, person: other))

        get form_answers_path(person_id: priya.id), headers: frame_headers

        expect(response.body).to include("priya-answer")
        expect(response.body).not_to include("sam-answer")
      end

      it "filters by submission" do
        mine = create(:form_submission)
        theirs = create(:form_submission)
        create(:form_answer, submitted_answer: "in-submission", form_submission: mine)
        create(:form_answer, submitted_answer: "other-submission", form_submission: theirs)

        get form_answers_path(form_submission_id: mine.id), headers: frame_headers

        expect(response.body).to include("in-submission")
        expect(response.body).not_to include("other-submission")
      end

      it "filters by question type" do
        form = create(:form)
        paragraph = create(:form_field, form: form, answer_type: :free_form_input_paragraph)
        one_line = create(:form_field, form: form, answer_type: :free_form_input_one_line)
        create(:form_answer, submitted_answer: "long-answer", form_field: paragraph)
        create(:form_answer, submitted_answer: "short-answer", form_field: one_line)

        get form_answers_path(answer_type: "free_form_input_paragraph"), headers: frame_headers

        expect(response.body).to include("long-answer")
        expect(response.body).not_to include("short-answer")
      end

      # By the submission's date, not the answer row's, so this list and a form's
      # results page answer the same date range the same way.
      it "filters by when the submission was made" do
        create(:form_answer, submitted_answer: "winter-answer",
               form_submission: create(:form_submission, created_at: Date.new(2026, 1, 5)))
        create(:form_answer, submitted_answer: "summer-answer",
               form_submission: create(:form_submission, created_at: Date.new(2026, 6, 5)))

        get form_answers_path(start_date: "2026-05-01", end_date: "2026-07-01"), headers: frame_headers

        expect(response.body).to include("summer-answer")
        expect(response.body).not_to include("winter-answer")
      end

      it "hides the blank answer rows an unfilled optional question leaves behind" do
        form = create(:form)
        create(:form_answer, submitted_answer: "answered-it",
               form_field: create(:form_field, form: form, name: "Answered question"))
        create(:form_answer, submitted_answer: "",
               form_field: create(:form_field, form: form, name: "Skipped question"))

        get form_answers_path, headers: frame_headers

        expect(response.body).to include("Answered question")
        expect(response.body).not_to include("Skipped question")
      end

      it "includes the blank rows when the empty filter asks for them" do
        form = create(:form)
        create(:form_answer, submitted_answer: "",
               form_field: create(:form_field, form: form, name: "Skipped question"))

        get form_answers_path(empty: "include"), headers: frame_headers

        expect(response.body).to include("Skipped question")
      end

      it "links back to the form's results page when it linked here" do
        form = create(:form, name: "Volunteer interest")
        create(:form_answer, form_submission: create(:form_submission, form: form))

        get form_answers_path(form_id: form.id, return_to: "form_results")

        expect(response.body).to include(CGI.escapeHTML(results_form_path(form)))
        expect(response.body).to include("Volunteer interest results")
      end

      it "keeps every filter on the round trip through a submission" do
        org = create(:organization)
        submission = create(:form_submission)
        submission.link_organization!(org.id)
        create(:form_answer, form_submission: submission)

        get form_answers_path(organization_id: org.id), headers: frame_headers

        expect(response.body).to include(CGI.escapeHTML(
          form_submission_path(submission, return_to: "form_answers", organization_id: org.id)
        ))
      end

      it "breaks the View link out of the results frame" do
        create(:form_answer)
        get form_answers_path, headers: frame_headers
        expect(response.body).to include('data-turbo-frame="_top"')
      end

      it "each View link returns to form answers" do
        answer = create(:form_answer)
        get form_answers_path, headers: frame_headers
        expect(response.body).to include(
          CGI.escapeHTML(form_submission_path(answer.form_submission, return_to: "form_answers"))
        )
      end
    end

    context "as a non-admin" do
      before { sign_in create(:user) }

      it "redirects away" do
        get form_answers_path

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
