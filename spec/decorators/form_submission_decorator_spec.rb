require "rails_helper"

RSpec.describe FormSubmissionDecorator do
  describe "#payer_name / #payer_email" do
    before { allow(Draper::ViewContext.current.send(:view_context)).to receive(:allowed_to?).with(:full_name?, anything).and_return(false) }

    it "uses the linked person's account, preferring the account email" do
      user = build(:user, email: "priya@example.com")
      person = build(:person, first_name: "Priya", last_name: "Patel", user: user, email: "typed@example.com")
      submission = build(:form_submission, person: person).decorate

      expect(submission.payer_name).to eq(person.name)
      expect(submission.payer_email).to eq("priya@example.com")
    end

    it "falls back to the submitted answers for an account-less payer" do
      submission = create(:form_submission, person: nil, role: "bulk_payment")
      first = create(:form_field, form: submission.form, field_identifier: "first_name", name: "First name")
      last = create(:form_field, form: submission.form, field_identifier: "last_name", name: "Last name")
      email = create(:form_field, form: submission.form, field_identifier: "primary_email", name: "Email")
      submission.form_answers.create!(form_field: first, submitted_answer: "Dana")
      submission.form_answers.create!(form_field: last, submitted_answer: "Doe")
      submission.form_answers.create!(form_field: email, submitted_answer: "dana@example.com")

      expect(submission.decorate.payer_name).to eq("Dana Doe")
      expect(submission.decorate.payer_email).to eq("dana@example.com")
    end

    it "returns a neutral placeholder when there is neither an account nor a typed name" do
      submission = create(:form_submission, person: nil, role: "bulk_payment").decorate

      expect(submission.payer_name).to eq("Anonymous payer")
      expect(submission.payer_email).to be_nil
    end
  end

  describe "#link_organization_effects" do
    let(:person) { create(:person, user: nil) }

    def submission_for(form, role: "public", event: nil, position: nil)
      submission = create(:form_submission, form: form, person: person, role: role, event: event)
      if position
        field = create(:form_field, form: form, field_identifier: "organization_position")
        submission.form_answers.create!(form_field: field, submitted_answer: position)
      end
      submission.decorate
    end

    it "names the on-demand registration and both affiliations" do
      training = create(:event, title: "On-Demand Training", facilitator_training: true, on_demand: true)
      create(:event_registration, event: training, registrant: person)
      submission = submission_for(create(:form, role: "registration"), event: training, position: "Counselor")

      expect(submission.link_organization_effects).to eq([
        "Links it to their On-Demand Training registration",
        "Adds a “Counselor” job affiliation there",
        "Adds a Facilitator affiliation there"
      ])
    end

    it "warns that a new-job agreement ends their other organizations' affiliations" do
      submission = submission_for(create(:form, role: "new_job"))

      expect(submission.link_organization_effects).to eq([
        "Adds a Facilitator affiliation there",
        "Ends their affiliations at other organizations"
      ])
    end

    it "lists only the job affiliation for a form without an agreement role" do
      submission = submission_for(create(:form), position: "Volunteer")

      expect(submission.link_organization_effects).to eq([ "Adds a “Volunteer” job affiliation there" ])
    end

    it "lists nothing for a close-program submission, which ends affiliations instead" do
      submission = submission_for(create(:form, role: "close_program"), position: "Director")

      expect(submission.link_organization_effects).to be_empty
    end
  end
end
