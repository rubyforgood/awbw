require "rails_helper"

RSpec.describe FormSubmission do
  describe "associations" do
    it { should belong_to(:person) }
    it { should belong_to(:form) }
    it { should belong_to(:event).optional }
    it { should have_many(:form_answers).dependent(:destroy) }
    it { should accept_nested_attributes_for(:form_answers) }
  end

  describe ".search_by_params" do
    it "returns all submissions when no filters are given" do
      a = create(:form_submission)
      b = create(:form_submission)

      expect(FormSubmission.search_by_params({})).to contain_exactly(a, b)
    end

    it "filters by form, role, event, and person" do
      form = create(:form)
      event = create(:event)
      person = create(:person)
      wanted = create(:form_submission, form: form, role: "registration", event: event, person: person)
      create(:form_submission, role: "scholarship")

      expect(FormSubmission.search_by_params(form_id: form.id, role: "registration",
                                             event_id: event.id, person_id: person.id)).to contain_exactly(wanted)
    end

    it "filters by several forms at once when form_id is an array" do
      agreement = create(:form)
      new_job = create(:form)
      on_agreement = create(:form_submission, form: agreement)
      on_new_job = create(:form_submission, form: new_job)
      create(:form_submission)

      expect(FormSubmission.search_by_params(form_id: [ agreement.id, new_job.id ]))
        .to contain_exactly(on_agreement, on_new_job)
    end

    it "ignores blank entries in a multi-form filter" do
      form = create(:form)
      wanted = create(:form_submission, form: form)
      create(:form_submission)

      expect(FormSubmission.search_by_params(form_id: [ "", form.id.to_s ])).to contain_exactly(wanted)
    end

    it "filters by submission date range on created_at, ignoring unparseable dates" do
      old = create(:form_submission, created_at: 2.years.ago)
      recent = create(:form_submission, created_at: Date.current)

      expect(FormSubmission.search_by_params(start_date: 1.month.ago.to_date.iso8601)).to contain_exactly(recent)
      expect(FormSubmission.search_by_params(end_date: "not-a-date")).to contain_exactly(old, recent)
    end

    it "filters by the organization linked directly to the submission" do
      organization = create(:organization)
      linked = create(:form_submission)
      linked.link_organization!(organization.id)
      create(:form_submission)

      expect(FormSubmission.search_by_params(organization_id: organization.id)).to contain_exactly(linked)
    end

    it "ignores an org reached only through the submission's event registration" do
      organization = create(:organization)
      event = create(:event)
      person = create(:person)
      create(:form_submission, person: person, event: event)
      registration = create(:event_registration, registrant: person, event: event)
      create(:event_registration_organization, event_registration: registration, organization: organization)

      expect(FormSubmission.search_by_params(organization_id: organization.id)).to be_empty
    end
  end

  describe "slug" do
    it "generates a unique slug for bulk payment submissions" do
      submission = create(:form_submission, role: "bulk_payment")

      expect(submission.slug).to be_present
    end

    it "leaves the slug blank for other submission roles" do
      submission = create(:form_submission, role: "registration")

      expect(submission.slug).to be_nil
    end
  end

  describe "#answers_by_identifier" do
    it "maps submitted answers by their field identifier" do
      form = create(:form)
      field = create(:form_field, form: form, field_identifier: "primary_email", name: "Email")
      submission = create(:form_submission, form: form)
      submission.form_answers.create!(form_field: field, submitted_answer: "pat@example.com")

      expect(submission.answers_by_identifier["primary_email"]).to eq("pat@example.com")
    end

    it "also indexes a legacy-spelled answer under its canonical identifier" do
      form = create(:form)
      field = create(:form_field, form: form, field_identifier: "payer_email", name: "Payer email")
      submission = create(:form_submission, form: form)
      submission.form_answers.create!(form_field: field, submitted_answer: "pat@example.com")

      answers = submission.answers_by_identifier
      expect(answers["payer_email"]).to eq("pat@example.com")
      expect(answers["primary_email"]).to eq("pat@example.com")
    end
  end

  describe "index filter scopes" do
    def submission_with_org_answer(org_name, person: create(:person, user: nil))
      submission = create(:form_submission, person: person)
      field = create(:form_field, form: submission.form, field_identifier: "organization_name")
      create(:form_answer, form_submission: submission, form_field: field, submitted_answer: org_name)
      submission
    end

    describe ".search" do
      it "matches the person's name or email" do
        person = create(:person, user: nil, first_name: "Priya", last_name: "Patel", email: "priya@example.com")
        mine = create(:form_submission, person: person)
        other = create(:form_submission)

        expect(described_class.search("Priya")).to include(mine)
        expect(described_class.search("priya@example.com")).to include(mine)
        expect(described_class.search("Priya")).not_to include(other)
      end
    end

    describe ".for_organization" do
      it "matches a metadata link and a pinned registration-org row alike" do
        organization = create(:organization)
        by_metadata = create(:form_submission)
        by_metadata.link_organization!(organization.id)
        by_pin = create(:form_submission)
        create(:event_registration_organization, form_submission: by_pin, organization: organization,
               event_registration: create(:event_registration, registrant: by_pin.person))
        unrelated = create(:form_submission)

        results = described_class.for_organization(organization.id)

        expect(results).to contain_exactly(by_metadata, by_pin)
        expect(results).not_to include(unrelated)
      end
    end

    describe ".org_link_status" do
      it "separates linked, pending, none, and unlinked by the direct submission link" do
        linked = submission_with_org_answer("Harbor Family Shelter")
        linked.link_organization!(create(:organization, name: "Harbor Family Shelter").id)
        pending = submission_with_org_answer("Lakeside College")
        no_answer = create(:form_submission)

        expect(described_class.org_link_status("linked")).to contain_exactly(linked)
        # Pending: gave an org answer, nothing linked yet — the actionable queue.
        expect(described_class.org_link_status("pending")).to contain_exactly(pending)
        # None: no organization answer provided.
        expect(described_class.org_link_status("none")).to contain_exactly(no_answer)
        # Unlinked is broad: pending + none (everything not linked).
        expect(described_class.org_link_status("unlinked")).to contain_exactly(pending, no_answer)
      end

      it "counts only a direct submission link, not a matching affiliation the person holds" do
        submission = submission_with_org_answer("Harbor Family Shelter")
        create(:affiliation, person: submission.person, organization: create(:organization, name: "Harbor Family Shelter"))

        # Still needs processing — nothing has been linked to the submission.
        expect(described_class.org_link_status("linked")).to be_empty
        expect(described_class.org_link_status("pending")).to contain_exactly(submission)
      end

      it "counts the registration-org row the submission is pinned to, with no metadata link" do
        submission = submission_with_org_answer("Harbor Family Shelter")
        create(:event_registration_organization, form_submission: submission,
               organization: create(:organization, name: "Harbor Family Shelter"),
               event_registration: create(:event_registration, registrant: submission.person))

        # Public registration pins the submission instead of writing metadata, so
        # this org is linked and the submission is out of the actionable queue.
        expect(described_class.org_link_status("linked")).to contain_exactly(submission)
        expect(described_class.org_link_status("pending")).to be_empty
        expect(described_class.org_link_status("unlinked")).to be_empty
      end

      it "counts an explicitly linked org even when the submitted name doesn't match it" do
        submission = submission_with_org_answer("Acme Inc")
        submission.link_organization!(create(:organization, name: "Acme Corporation").id)

        expect(described_class.org_link_status("linked")).to contain_exactly(submission)
        expect(described_class.org_link_status("pending")).to be_empty
      end
    end

    describe "#link_organization!" do
      it "records ids in metadata without duplicates and resolves them to orgs" do
        submission = create(:form_submission)
        organization = create(:organization)

        submission.link_organization!(organization.id)
        submission.link_organization!(organization.id)

        expect(submission.reload.linked_organization_ids).to eq([ organization.id ])
        expect(submission.linked_organizations).to contain_exactly(organization)
      end
    end

    describe ".account_status" do
      it "separates no-account, invited, and has-access people" do
        no_account = create(:form_submission, person: create(:person, user: nil))
        invited = create(:form_submission)
        invited.person.user.update_columns(confirmed_at: nil, welcome_instructions_sent_at: Time.current)
        confirmed = create(:form_submission)
        confirmed.person.user.update_columns(confirmed_at: Time.current, locked_at: nil, inactive: false)

        expect(described_class.account_status("none")).to contain_exactly(no_account)
        expect(described_class.account_status("invited")).to contain_exactly(invited)
        expect(described_class.account_status("has_access")).to include(confirmed)
      end
    end
  end

  describe "#bulk_payment_attendees" do
    let(:form) { create(:form) }
    let(:field) { create(:form_field, form: form, field_identifier: "bulk_payment_attendees", name: "Attendees") }
    let(:submission) { create(:form_submission, form: form) }

    it "parses the attendees JSON array" do
      submission.form_answers.create!(form_field: field, submitted_answer: [ { first_name: "A", email: "a@example.com" } ].to_json)

      expect(submission.bulk_payment_attendees).to eq([ { "first_name" => "A", "email" => "a@example.com" } ])
    end

    it "returns an empty array for invalid JSON" do
      submission.form_answers.create!(form_field: field, submitted_answer: "not json")

      expect(submission.bulk_payment_attendees).to eq([])
    end
  end

  describe "#bulk_payment_amount_cents" do
    let(:event) { create(:event, cost_cents: 2500) }
    let(:form) { create(:form) }
    let(:submission) { create(:form_submission, form: form) }

    it "multiplies the event cost by the number of attendees submitted" do
      field = create(:form_field, form: form, field_identifier: "number_of_attendees", name: "Attendees")
      submission.form_answers.create!(form_field: field, submitted_answer: "3")

      expect(submission.bulk_payment_amount_cents(event)).to eq(7500)
    end

    it "falls back to the count of submitted attendees when no count is given" do
      field = create(:form_field, form: form, field_identifier: "bulk_payment_attendees", name: "Attendees")
      submission.form_answers.create!(form_field: field,
                                      submitted_answer: [ { first_name: "A" }, { first_name: "B" } ].to_json)

      expect(submission.bulk_payment_amount_cents(event)).to eq(5000)
    end

    it "returns zero when the event has no cost" do
      free_event = create(:event, cost_cents: 0)
      field = create(:form_field, form: form, field_identifier: "number_of_attendees", name: "Attendees")
      submission.form_answers.create!(form_field: field, submitted_answer: "3")

      expect(submission.bulk_payment_amount_cents(free_event)).to eq(0)
    end
  end

  describe "linked registrations" do
    let(:event) { create(:event) }
    let(:form) { create(:form) }
    let(:submission) { create(:form_submission, form: form, event: event) }
    let!(:reg1) { create(:event_registration, event: event) }
    let!(:reg2) { create(:event_registration, event: event) }

    describe "#linked_registration_ids" do
      it "returns an empty array when metadata is nil" do
        expect(submission.linked_registration_ids).to eq([])
      end

      it "returns an empty array when metadata has no linked_registration_ids" do
        submission.update!(metadata: { "other_key" => "value" })
        expect(submission.linked_registration_ids).to eq([])
      end

      it "returns the stored ids" do
        submission.update!(metadata: { "linked_registration_ids" => [ reg1.id, reg2.id ] })
        expect(submission.linked_registration_ids).to contain_exactly(reg1.id, reg2.id)
      end
    end

    describe "#link_registration!" do
      it "adds a registration id to metadata" do
        submission.link_registration!(reg1.id)

        expect(submission.reload.linked_registration_ids).to eq([ reg1.id ])
      end

      it "does not duplicate an existing id" do
        submission.link_registration!(reg1.id)
        submission.link_registration!(reg1.id)

        expect(submission.reload.linked_registration_ids).to eq([ reg1.id ])
      end

      it "preserves other metadata" do
        submission.update!(metadata: { "other_key" => "value" })
        submission.link_registration!(reg1.id)

        expect(submission.reload.metadata["other_key"]).to eq("value")
        expect(submission.linked_registration_ids).to eq([ reg1.id ])
      end
    end

    describe "#record_callout_collection!" do
      let(:callout) { create(:registration_ticket_callout) }

      it "flags the submission as callout-collected without touching other metadata" do
        submission.update!(metadata: { "other_key" => "value" })
        submission.record_callout_collection!(callout)

        expect(submission.reload.collected_via_callout?).to be(true)
        expect(submission.metadata["collected_via_callout_id"]).to eq(callout.id)
        expect(submission.metadata["other_key"]).to eq("value")
      end

      it "reads false when nothing recorded it" do
        expect(submission.collected_via_callout?).to be(false)
      end
    end

    describe "#unlink_registration!" do
      it "removes a registration id from metadata" do
        submission.link_registration!(reg1.id)
        submission.link_registration!(reg2.id)
        submission.unlink_registration!(reg1.id)

        expect(submission.reload.linked_registration_ids).to eq([ reg2.id ])
      end

      it "is a no-op when the id is not linked" do
        submission.link_registration!(reg1.id)
        submission.unlink_registration!(reg2.id)

        expect(submission.reload.linked_registration_ids).to eq([ reg1.id ])
      end
    end

    describe "#linked_registrations" do
      it "returns event registrations matching linked ids" do
        submission.link_registration!(reg1.id)
        submission.link_registration!(reg2.id)

        expect(submission.linked_registrations).to contain_exactly(reg1, reg2)
      end

      it "returns empty relation when nothing is linked" do
        expect(submission.linked_registrations).to be_empty
      end
    end
  end

  describe "#persist_answer" do
    let(:submission) { create(:form_submission) }

    it "stores a text answer with the field's name" do
      field = create(:form_field, form: submission.form, name: "Message")
      submission.persist_answer(field, "Hello there")

      answer = submission.form_answers.find_by(form_field: field)
      expect(answer.submitted_answer).to eq("Hello there")
      expect(answer.question_name_when_answered).to eq("Message")
    end

    it "comma-joins a multi-value answer, dropping blanks" do
      field = create(:form_field, form: submission.form, answer_type: :multi_select_checkbox)
      submission.persist_answer(field, [ "A", "", "B" ])

      expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("A, B")
    end

    it "updates the existing answer rather than duplicating it" do
      field = create(:form_field, form: submission.form)
      submission.persist_answer(field, "first")
      submission.persist_answer(field, "second")

      expect(submission.form_answers.where(form_field: field).count).to eq(1)
      expect(submission.form_answers.find_by(form_field: field).submitted_answer).to eq("second")
    end

    it "raises UnreadableUpload for a forged file-upload signed id" do
      field = create(:form_field, :file_upload, form: submission.form)

      expect { submission.persist_answer(field, "forged-signed-id") }
        .to raise_error(FormSubmission::UnreadableUpload)
    end
  end
end
