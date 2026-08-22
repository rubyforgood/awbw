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
        expect(response.body).to include("Form answers")
      end

      it "searches by answer text" do
        wanted = create(:form_answer, submitted_answer: "Loves painting murals")
        other = create(:form_answer, submitted_answer: "Prefers sculpture")

        get form_answers_path(q: "murals"), headers: frame_headers

        expect(response.body).to include("Loves painting murals")
        expect(response.body).not_to include("Prefers sculpture")
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

      it "filters by person name" do
        priya = create(:person, first_name: "Priya", last_name: "Patel")
        other = create(:person, first_name: "Sam", last_name: "Jones")
        create(:form_answer, submitted_answer: "priya-answer",
               form_submission: create(:form_submission, person: priya))
        create(:form_answer, submitted_answer: "sam-answer",
               form_submission: create(:form_submission, person: other))

        get form_answers_path(person: "Priya"), headers: frame_headers

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
