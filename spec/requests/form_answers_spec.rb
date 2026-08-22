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

  describe "POST /form_answers/:id/promote_to_quote" do
    let(:submitter) { create(:user, :with_person) }
    let(:field) { create(:form_field, field_identifier: "quote") }
    let(:answer) do
      create(:form_answer, submitted_answer: "Painting gave me a voice",
             form_field: field,
             form_submission: create(:form_submission, person: submitter.person))
    end

    context "as an admin" do
      before { sign_in admin }

      it "creates a quote with no author, crediting the submitter as creator" do
        expect { post promote_to_quote_form_answer_path(answer) }.to change(Quote, :count).by(1)

        quote = Quote.last
        expect(quote.body).to eq("Painting gave me a voice")
        expect(quote.author).to be_nil
        expect(quote.created_by).to eq(submitter)
        expect(quote.author_credit).to eq("Participant")
        expect(response).to redirect_to(edit_quote_path(quote))
      end

      it "does not create a quote from a blank answer" do
        answer.update!(submitted_answer: "")

        expect { post promote_to_quote_form_answer_path(answer) }.not_to change(Quote, :count)
        expect(response).to redirect_to(form_answers_path)
      end

      it "reuses the existing quote when the same answer is promoted again" do
        post promote_to_quote_form_answer_path(answer)
        quote = Quote.last

        expect { post promote_to_quote_form_answer_path(answer) }.not_to change(Quote, :count)
        expect(response).to redirect_to(edit_quote_path(quote))
      end

      it "still recognizes the answer after the published body was edited" do
        post promote_to_quote_form_answer_path(answer)
        quote = Quote.last
        quote.update!(body: "An edited, published version")

        expect { post promote_to_quote_form_answer_path(answer) }.not_to change(Quote, :count)
        expect(response).to redirect_to(edit_quote_path(quote))
      end
    end

    context "as a non-admin" do
      before { sign_in create(:user) }

      it "is forbidden and creates nothing" do
        expect { post promote_to_quote_form_answer_path(answer) }.not_to change(Quote, :count)
        expect(response).not_to have_http_status(:ok)
      end
    end
  end
end
