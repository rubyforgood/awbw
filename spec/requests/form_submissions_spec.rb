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

      it "filters by role" do
        registration = create(:form_submission, role: "registration")
        scholarship = create(:form_submission, role: "scholarship")

        get form_submissions_path(role: "registration"), headers: frame_headers

        expect(response.body).to include(form_submission_path(registration))
        expect(response.body).not_to include(form_submission_path(scholarship))
      end

      it "filters by event" do
        event = create(:event)
        here = create(:form_submission, event: event)
        elsewhere = create(:form_submission, event: create(:event))

        get form_submissions_path(event_id: event.id), headers: frame_headers

        expect(response.body).to include(form_submission_path(here))
        expect(response.body).not_to include(form_submission_path(elsewhere))
      end

      it "filters by submission date range" do
        old = create(:form_submission, created_at: 1.year.ago)
        recent = create(:form_submission, created_at: Date.current)

        get form_submissions_path(start_date: 1.week.ago.to_date.iso8601), headers: frame_headers

        expect(response.body).to include(form_submission_path(recent))
        expect(response.body).not_to include(form_submission_path(old))
      end

      it "filters by organization through its registration link" do
        organization = create(:organization)
        linked = create(:form_submission)
        other = create(:form_submission)
        create(:event_registration_organization, organization: organization, form_submission: linked)

        get form_submissions_path(organization_id: organization.id), headers: frame_headers

        expect(response.body).to include(form_submission_path(linked))
        expect(response.body).not_to include(form_submission_path(other))
      end

      it "carries the new filters back through each View link" do
        event = create(:event)
        submission = create(:form_submission, event: event, role: "registration")

        get form_submissions_path(event_id: event.id, role: "registration"), headers: frame_headers

        expect(response.body).to include(
          CGI.escapeHTML(form_submission_path(submission, return_to: "form_submissions",
                                              person_id: submission.person_id, event_id: event.id, role: "registration"))
        )
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

      it "keeps the forms origin on the filter form so changing the filter doesn't lose it" do
        form = create(:form, name: "Volunteer interest")
        get form_submissions_path(form_id: form.id, return_to: "forms")

        expect(response.body).to include('name="return_to"')
        expect(response.body).to include('value="forms"')
      end

      it "each View link carries the origin so the Forms eyebrow survives the round trip" do
        form = create(:form, name: "Volunteer interest")
        submission = create(:form_submission, form: form)

        get form_submissions_path(form_id: form.id, return_to: "forms"), headers: frame_headers

        expect(response.body).to include(
          CGI.escapeHTML(form_submission_path(submission, return_to: "form_submissions", origin: "forms",
                                              person_id: submission.person_id, form_id: form.id))
        )
      end

      it "each View link carries the form filter so the trip back keeps it" do
        form = create(:form, name: "Volunteer interest")
        submission = create(:form_submission, form: form)

        get form_submissions_path(form_id: form.id), headers: frame_headers

        expect(response.body).to include(
          CGI.escapeHTML(form_submission_path(submission, return_to: "form_submissions",
                                              person_id: submission.person_id, form_id: form.id))
        )
      end

      it "each View link carries a return_to back to the person's index" do
        person = create(:person)
        submission = create(:form_submission, person: person)

        get form_submissions_path(person_id: person.id), headers: frame_headers

        expect(response.body).to include(
          CGI.escapeHTML(form_submission_path(submission, return_to: "form_submissions", person_id: person.id))
        )
      end

      it "shows the submitted organization with whether it is linked to the person" do
        submission = create(:form_submission)
        org_field = create(:form_field, form: submission.form, name: "Organization name",
                           field_identifier: "organization_name")
        create(:form_answer, form_submission: submission, form_field: org_field,
               submitted_answer: "Harbor Family Shelter")

        get form_submissions_path, headers: frame_headers
        expect(response.body).to include("Harbor Family Shelter")
        expect(response.body).to include("Not linked")

        create(:affiliation, person: submission.person,
               organization: create(:organization, name: "Harbor Family Shelter"))
        get form_submissions_path, headers: frame_headers
        expect(response.body).to include("Linked")
      end

      it "filters by person name via the search box" do
        person = create(:person, user: nil, first_name: "Priya", last_name: "Patel")
        mine = create(:form_submission, person: person)
        theirs = create(:form_submission)

        get form_submissions_path(search: "Priya"), headers: frame_headers

        expect(response.body).to include(form_submission_path(mine))
        expect(response.body).not_to include(form_submission_path(theirs))
      end

      it "filters agreement submissions across forms with the scenario filter" do
        job_change = create(:form_submission, form: create(:form, purpose: "job_change_agreement"))
        on_demand = create(:form_submission, form: create(:form, purpose: "on_demand_agreement"))
        plain = create(:form_submission)

        get form_submissions_path(scenario: "any"), headers: frame_headers
        expect(response.body).to include(form_submission_path(job_change), form_submission_path(on_demand))
        expect(response.body).not_to include(form_submission_path(plain))

        get form_submissions_path(scenario: "job_change_agreement"), headers: frame_headers
        expect(response.body).to include(form_submission_path(job_change))
        expect(response.body).not_to include(form_submission_path(on_demand))
      end

      it "filters by submitted date range" do
        old = create(:form_submission, created_at: Date.new(2026, 1, 10))
        recent = create(:form_submission, created_at: Date.new(2026, 8, 10))

        get form_submissions_path(start_date: "2026-06-01", end_date: "2026-08-31"), headers: frame_headers

        expect(response.body).to include(form_submission_path(recent))
        expect(response.body).not_to include(form_submission_path(old))
      end

      it "shows the person's account status with an invite or create-user action" do
        no_account = create(:form_submission, person: create(:person, user: nil))
        with_account = create(:form_submission)
        with_account.person.user.update_columns(confirmed_at: nil, welcome_instructions_sent_at: nil)

        get form_submissions_path, headers: frame_headers

        expect(response.body).to include(new_user_path(person_id: no_account.person_id))
        expect(response.body).to include(
          CGI.escapeHTML(send_welcome_instructions_user_path(with_account.person.user,
                                                             return_to: "form_submission",
                                                             form_submission_id: with_account.id))
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

      it "carries the form filter back when arriving from the form-filtered index" do
        get form_submission_path(submission, return_to: "form_submissions", form_id: submission.form_id)

        expect(response.body).to include(
          CGI.escapeHTML(form_submissions_path(form_id: submission.form_id))
        )
      end

      it "hands the index back its own origin so the Forms eyebrow is restored" do
        get form_submission_path(submission, return_to: "form_submissions", origin: "forms",
                                 form_id: submission.form_id)

        expect(response.body).to include(
          CGI.escapeHTML(form_submissions_path(form_id: submission.form_id, return_to: "forms"))
        )
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

    context "processing panel for agreement scenario forms" do
      before { sign_in admin }

      let(:form) { create(:form, purpose: "job_change_agreement", name: "Collaboration agreement (job change)") }
      let(:person) { create(:person, user: nil) }
      let(:submission) { create(:form_submission, form: form, person: person) }

      it "is absent on a form without a purpose" do
        plain = create(:form_submission)

        get form_submission_path(plain)

        expect(response.body).not_to include("Processing")
      end

      it "shows the scenario, submitted organization, affiliations, and account status" do
        org_field = create(:form_field, form: form, name: "Organization name", field_identifier: "organization_name")
        create(:form_answer, form_submission: submission, form_field: org_field, submitted_answer: "New Org")
        create(:affiliation, person: person, organization: create(:organization, name: "Old Org"))

        get form_submission_path(submission)

        expect(response.body).to include("Job change agreement")
        expect(response.body).to include("New Org")
        expect(response.body).to include("Old Org")
        expect(response.body).to include(new_user_path(person_id: person.id))
        expect(response.body).to include(
          CGI.escapeHTML(edit_person_path(person, return_to: "form_submission",
                                          form_submission_id: submission.id, anchor: "affiliations"))
        )
      end

      it "offers a one-click End (dated to the submission) for an active affiliation on a job change" do
        affiliation = create(:affiliation, person: person, organization: create(:organization, name: "Old Org"))

        get form_submission_path(submission)

        expect(response.body).to include(
          CGI.escapeHTML(end_affiliation_path(affiliation, form_submission_id: submission.id,
                                              end_date: submission.created_at.to_date.iso8601))
        )
      end

      it "offers no End button outside the job change scenario" do
        reinstatement = create(:form_submission, person: person,
                               form: create(:form, purpose: "reinstatement_agreement"))
        affiliation = create(:affiliation, person: person, organization: create(:organization))

        get form_submission_path(reinstatement)

        expect(response.body).to include("Returning facilitator")
        expect(response.body).not_to include(end_affiliation_path(affiliation))
      end
    end

    context "organization linking for a submission" do
      let(:form) { create(:form, purpose: "job_change_agreement", name: "Collaboration agreement (job change)") }
      let(:person) { create(:person, user: nil) }
      let(:submission) { create(:form_submission, form: form, person: person) }

      def add_answer(identifier, value)
        field = form.form_fields.find_by(field_identifier: identifier) ||
                create(:form_field, form: form, field_identifier: identifier)
        create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
      end

      before { sign_in admin }

      describe "GET /form_submissions/:id/link_organization" do
        it "offers a create-and-link row for a submitted org that isn't in the database" do
          add_answer("organization_name", "Lakeside Community College")
          add_answer("organization_position", "Counselor")

          get link_organization_form_submission_path(submission)

          expect(response.body).to include("Lakeside Community College")
          expect(response.body).to include("Create and link")
          expect(response.body).to include("Pending")
          expect(response.body).to include(CGI.escapeHTML(create_organization_form_submission_path(submission)))
        end

        it "shows the matched organization when an active affiliation matches the submitted name" do
          add_answer("organization_name", "Harbor Family Shelter")
          create(:affiliation, person: person, organization: create(:organization, name: "Harbor Family Shelter"))

          get link_organization_form_submission_path(submission)

          expect(response.body).to include("Harbor Family Shelter")
          expect(response.body).not_to include("Create and link")
          expect(response.body).to include("Affiliations:")
        end
      end

      describe "POST /form_submissions/:id/select_organization" do
        it "creates the job and Facilitator affiliations, dating the facilitator one to the submission" do
          add_answer("organization_name", "Harbor Family Shelter")
          add_answer("organization_position", "Counselor")
          organization = create(:organization, name: "Harbor Family Shelter")

          post select_organization_form_submission_path(submission, organization_id: organization.id)

          titles = person.affiliations.where(organization: organization).pluck(:title, :start_date)
          expect(titles).to contain_exactly([ "Counselor", nil ], [ "Facilitator", submission.created_at.to_date ])
          expect(response).to redirect_to(link_organization_form_submission_path(submission))
        end

        it "creates only the job affiliation for a form without an agreement purpose" do
          plain_form = create(:form)
          plain = create(:form_submission, form: plain_form, person: person)
          field = create(:form_field, form: plain_form, field_identifier: "organization_position")
          create(:form_answer, form_submission: plain, form_field: field, submitted_answer: "Volunteer")
          organization = create(:organization)

          post select_organization_form_submission_path(plain, organization_id: organization.id)

          expect(person.affiliations.where(organization: organization).pluck(:title)).to eq([ "Volunteer" ])
        end

        it "records the explicit link so a resolved name mismatch still reads as linked" do
          add_answer("organization_name", "Acme Inc")
          organization = create(:organization, name: "Acme Corporation")

          post select_organization_form_submission_path(submission, organization_id: organization.id)

          expect(submission.reload.linked_organization_ids).to eq([ organization.id ])

          get link_organization_form_submission_path(submission)
          expect(response.body).to include("Acme Corporation")
          expect(response.body).not_to include("No organization linked")
        end

        it "fills blank org profile fields from the submission and flags conflicting ones" do
          add_answer("organization_name", "Harbor Family Shelter")
          add_answer("organization_website", "https://harbor.example.org")
          organization = create(:organization, name: "Harbor Family Shelter", agency_type: "School")
          field = form.form_fields.find_by(field_identifier: "organization_type") ||
                  create(:form_field, form: form, field_identifier: "organization_type")
          create(:form_answer, form_submission: submission, form_field: field, submitted_answer: "Government Agency")

          post select_organization_form_submission_path(submission, organization_id: organization.id)

          expect(organization.reload.website_url).to eq("https://harbor.example.org")
          expect(organization.agency_type).to eq("School")
          expect(flash[:warning]).to include("differ")
        end
      end

      describe "POST /form_submissions/:id/create_organization" do
        it "creates the organization from the submitted name and links it" do
          create(:organization_status, name: "Active")
          add_answer("organization_name", "Lakeside Community College")
          add_answer("organization_position", "Counselor")

          expect {
            post create_organization_form_submission_path(submission)
          }.to change(Organization, :count).by(1)

          organization = Organization.find_by(name: "Lakeside Community College")
          expect(person.affiliations.where(organization: organization).pluck(:title)).to contain_exactly("Counselor", "Facilitator")
        end

        it "reuses an existing organization with the submitted name instead of duplicating it" do
          add_answer("organization_name", "harbor family shelter")
          existing = create(:organization, name: "Harbor Family Shelter")

          expect {
            post create_organization_form_submission_path(submission)
          }.not_to change(Organization, :count)

          expect(person.affiliations.where(organization: existing)).to exist
        end

        it "refuses when no organization name was submitted" do
          expect {
            post create_organization_form_submission_path(submission)
          }.not_to change(Organization, :count)

          expect(flash[:alert]).to include("No submitted organization name")
        end
      end

      context "as a non-admin" do
        before { sign_in create(:user) }

        it "denies the editor and the link actions" do
          organization = create(:organization)

          get link_organization_form_submission_path(submission)
          expect(response).to redirect_to(root_path)

          post select_organization_form_submission_path(submission, organization_id: organization.id)
          expect(person.affiliations).to be_empty
        end
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
