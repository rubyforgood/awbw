require "rails_helper"

RSpec.describe "Callout inline form", type: :request do
  let(:event) { create(:event, published: true) }
  let(:registration) { create(:event_registration, event:) }
  let(:form) { create(:form, name: "Feedback") }
  let!(:field) { create(:form_field, form:, name: "How was it?") }
  let(:callout) { create(:registration_ticket_callout, event:, form:, description: "") }

  describe "GET /registration/:slug/forms/:callout_id" do
    it "renders the form for the registrant" do
      get registration_callout_form_path(registration.slug, callout)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("callout_form[form_fields][#{field.id}]")
      expect(response.body).to include("Feedback")
    end

    it "redirects to the ticket when the callout has no form" do
      plain = create(:registration_ticket_callout, event:, description: "<p>Hi</p>")
      get registration_callout_form_path(registration.slug, plain)

      expect(response).to redirect_to(registration_ticket_path(registration.slug))
    end

    it "shows linked resources above the form, returning to the form page" do
      resource = create(:resource, title: "Worksheet")
      callout.resources << resource

      get registration_callout_form_path(registration.slug, callout)

      expect(response.body).to include("Worksheet")
      expect(response.body.index("Worksheet")).to be < response.body.index("callout_form[form_fields]")
      expect(response.body).to include(CGI.escapeHTML(
        registration_resource_path(registration.slug, resource, return_to: "callout_form", callout_id: callout.id)
      ))
    end
  end

  describe "POST /registration/:slug/forms/:callout_id" do
    it "records the submission and shows the answers back" do
      expect {
        post registration_callout_form_submit_path(registration.slug, callout, form),
             params: { callout_form: { form_fields: { field.id.to_s => "Loved it" } } }
      }.to change(FormSubmission, :count).by(1)

      submission = FormSubmission.last
      expect(submission).to have_attributes(person: registration.registrant, form:, event:, role: nil)
      expect(submission.collected_via_callout?).to be(true)
      expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("Loved it")

      follow_redirect!
      expect(response.body).to include("Completed")
      expect(response.body).to include("Loved it")
    end
  end

  describe "a form not set to anonymous, with optional name and email questions" do
    let!(:email) { create(:form_field, form:, name: "Email", field_identifier: "primary_email", required: false) }

    it "keeps them optional, since the ticket already names the registrant" do
      get registration_callout_form_path(registration.slug, callout)

      expect(response.body).not_to match(/name="callout_form\[form_fields\]\[#{email.id}\]"[^>]*required/)
    end

    it "credits the registrant without them" do
      post registration_callout_form_submit_path(registration.slug, callout, form),
           params: { callout_form: { form_fields: { field.id.to_s => "Loved it" } } }

      expect(FormSubmission.last.person).to eq(registration.registrant)
    end
  end

  describe "an anonymous form" do
    let(:form) { create(:form, name: "Feedback", anonymous: true) }

    def post_answers(answers = { field.id.to_s => "Loved it" })
      post registration_callout_form_submit_path(registration.slug, callout, form),
           params: { callout_form: { form_fields: answers } }
    end

    it "records the answers with no person, and marks the registrant as having completed it" do
      expect { post_answers }.to change(FormSubmission, :count).by(1)
        .and change(FormCompletion, :count).by(1)

      expect(FormSubmission.last.person).to be_nil
      expect(FormCompletion.last).to have_attributes(person: registration.registrant, form:, event:)
    end

    it "shows the form as completed without showing the answers back or offering an edit" do
      post_answers
      follow_redirect!

      expect(response.body).to include("Completed")
      expect(response.body).to include("submitted anonymously")
      expect(response.body).not_to include("Loved it")
      expect(response.body).not_to include("Edit responses")
      expect(response.body).not_to include("callout_form[form_fields][#{field.id}]")
    end

    it "refuses a second submission" do
      post_answers

      expect { post_answers({ field.id.to_s => "Again" }) }.not_to change(FormSubmission, :count)
      expect(response).to redirect_to(registration_callout_form_path(registration.slug, callout, anchor: "form-#{form.id}"))
    end

    it "ignores ?edit once the form is completed" do
      post_answers

      get registration_callout_form_path(registration.slug, callout, edit: form.id)

      expect(response.body).not_to include("callout_form[form_fields][#{field.id}]")
    end

    it "re-shows the form with an alert when a required question is blank" do
      field.update!(required: true)

      expect { post_answers({ field.id.to_s => "" }) }.not_to change(FormSubmission, :count)
      follow_redirect!

      expect(flash[:alert]).to be_present
      expect(response.body).to include("callout_form[form_fields][#{field.id}]")
    end

    it "tells the registrant their answers aren't tied to their name" do
      get registration_callout_form_path(registration.slug, callout)

      expect(response.body).to include("linked to your name")
    end

    it "stays anonymous when the registrant is logged in" do
      sign_in registration.registrant.user

      post_answers

      expect(FormSubmission.last.person).to be_nil
    end

    it "stamps no creator or editor on what a logged-in registrant submits" do
      sign_in registration.registrant.user

      post_answers

      submission = FormSubmission.last
      expect(submission).to have_attributes(created_by: nil, updated_by: nil)
      expect(submission.form_answers.map(&:created_by)).to all(be_nil)
      expect(submission.form_answers.map(&:updated_by)).to all(be_nil)
    end

    it "sends staff an FYI that names no one" do
      registration.registrant.update!(first_name: "Ada", last_name: "Lovelace")

      expect { post_answers }.to have_enqueued_mail(NotificationMailer, :callout_form_submitted_fyi)
    end

    context "with name and email questions" do
      let!(:first_name) { create(:form_field, form:, name: "First name", field_identifier: "first_name", required: true) }
      let!(:last_name) { create(:form_field, form:, name: "Last name", field_identifier: "last_name", required: true) }
      let!(:email) { create(:form_field, form:, name: "Email", field_identifier: "primary_email", required: true) }

      def identity(first: "Sam", last: "Rivera", address: "sam@example.com")
        { first_name.id.to_s => first, last_name.id.to_s => last, email.id.to_s => address, field.id.to_s => "Loved it" }
      end

      it "renders them as optional" do
        get registration_callout_form_path(registration.slug, callout)

        expect(response.body).not_to match(/name="callout_form\[form_fields\]\[#{email.id}\]"[^>]*required/)
      end

      it "credits the registrant who fills in all three, and shows their answers back" do
        post_answers(identity)

        expect(FormSubmission.last.person).to eq(registration.registrant)
        follow_redirect!
        expect(response.body).to include("Loved it")
      end

      it "stays anonymous on a partial answer" do
        post_answers(identity(address: ""))

        expect(FormSubmission.last.person).to be_nil
      end

      context "set to logged out only, with the registrant logged in" do
        before do
          [ first_name, last_name, email ].each { |f| f.update!(visibility: :logged_out_only) }
          sign_in registration.registrant.user
        end

        it "stays anonymous when they're skipped" do
          post_answers({ field.id.to_s => "Loved it" })

          expect(FormSubmission.last.person).to be_nil
        end

        it "credits the registrant when all three are answered" do
          post_answers(identity)

          expect(FormSubmission.last.person).to eq(registration.registrant)
        end
      end
    end
  end

  # The callout row's own display date withholds its page content (the card still
  # shows on the ticket), so it has to gate the forms it delivers too — not just
  # each row's own date.
  describe "a callout whose own display date has not arrived" do
    let(:dripping_callout) do
      create(:registration_ticket_callout, event:, form:, description: "",
             display_from: 1.day.from_now)
    end

    it "withholds the form from the page" do
      get registration_callout_form_path(registration.slug, dripping_callout)

      expect(response.body).not_to include("callout_form[form_fields][#{field.id}]")
      expect(response.body).to include("Available")
    end

    it "refuses a submission posted straight at the endpoint" do
      expect {
        post registration_callout_form_submit_path(registration.slug, dripping_callout, form),
             params: { callout_form: { form_fields: { field.id.to_s => "Too early" } } }
      }.not_to change(FormSubmission, :count)
    end

    it "opens the form once that date passes" do
      dripping_callout.update!(display_from: 1.day.ago)

      get registration_callout_form_path(registration.slug, dripping_callout)

      expect(response.body).to include("callout_form[form_fields][#{field.id}]")
    end
  end

  describe "a callout that delivers several forms, each on its own drip date" do
    let(:day1) { create(:form, name: "Day 1 Survey") }
    let(:day2) { create(:form, name: "Day 2 Survey") }
    let!(:day1_field) { create(:form_field, form: day1, name: "Day 1 highlight?") }
    let!(:day2_field) { create(:form_field, form: day2, name: "Day 2 highlight?") }
    let(:multi_callout) { create(:registration_ticket_callout, event:, description: "") }

    before do
      multi_callout.registration_ticket_callout_forms.create!(form: day1, display_from: 1.day.ago)
      multi_callout.registration_ticket_callout_forms.create!(form: day2, display_from: 1.day.from_now)
    end

    it "renders the live form and gates the not-yet-open one" do
      get registration_callout_form_path(registration.slug, multi_callout)

      expect(response.body).to include("Day 1 Survey").and include("Day 2 Survey")
      expect(response.body).to include("callout_form[form_fields][#{day1_field.id}]")
      # The dripping Day 2 form shows an "Available" chip, not its fillable field.
      expect(response.body).to include("Available")
      expect(response.body).not_to include("callout_form[form_fields][#{day2_field.id}]")
    end

    it "collapses a completed form under a Completed chip while others stay fillable" do
      post registration_callout_form_submit_path(registration.slug, multi_callout, day1),
        params: { callout_form: { form_fields: { day1_field.id.to_s => "Loved day 1" } } }

      get registration_callout_form_path(registration.slug, multi_callout)
      expect(response.body).to include("Completed")
      expect(response.body).to include("Loved day 1")
    end
  end

  describe "submitting a survey-role form (clarity fan-out + profile write-through)" do
    let(:survey) { create(:form, name: "Day 1 survey", role: "day_1_survey") }
    let!(:impact) { create(:form_field, form: survey, name: "Impact?", field_identifier: "impact") }
    let!(:anon) do
      create(:form_field, form: survey, answer_type: :single_select_radio, name: "Anonymity?",
        field_identifier: "anonymous_contributions")
    end
    let(:resource) { create(:resource, title: "Triple Focus") }
    let!(:clarity_field) do
      create(:form_field, form: survey, answer_type: :single_select_radio, name: "Was it clear for")
    end
    let(:survey_callout) { create(:registration_ticket_callout, event:, form: survey) }

    before { create(:form_field_resource, form_field: clarity_field, resource:) }

    it "records the fixed answers, fans clarity out per resource, and writes the profile through" do
      post registration_callout_form_submit_path(registration.slug, survey_callout, survey), params: {
        callout_form: {
          form_fields: {
            impact.id.to_s => "Transformative",
            anon.id.to_s => Person::ANONYMOUS_CONTRIBUTIONS_OPTIONS[true],
            clarity_field.id.to_s => { resource.id.to_s => "Yes" }
          }
        }
      }

      submission = FormSubmission.last
      expect(submission.role).to eq("day_1_survey")
      expect(submission.form_answers.find_by(form_field: impact).submitted_answer).to eq("Transformative")
      clarity_answer = submission.form_answers.find_by(form_field: nil)
      expect(clarity_answer.submitted_answer).to eq("Yes")
      expect(clarity_answer.question_name_when_answered).to eq("Was it clear for Triple Focus")
      expect(registration.registrant.reload.anonymous_contributions).to be(true)
    end
  end

  describe "the generic event-scoped page" do
    it "shows a preview note instead of the interactive form" do
      get event_registration_ticket_callout_path(event, callout, reg: registration.slug)

      expect(response.body).to include("Registrants fill out")
      expect(response.body).not_to include("callout_form[form_fields]")
    end
  end
end
