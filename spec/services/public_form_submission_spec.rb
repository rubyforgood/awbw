require "rails_helper"

RSpec.describe PublicFormSubmission do
  let(:form) { create(:form, slug: "volunteer-interest", published: true) }

  let!(:first_name_field) { create(:form_field, form: form, name: "First name", field_identifier: "first_name") }
  let!(:last_name_field)  { create(:form_field, form: form, name: "Last name", field_identifier: "last_name") }
  let!(:email_field)      { create(:form_field, form: form, name: "Email", field_identifier: "primary_email") }
  let!(:question_field)   { create(:form_field, form: form, name: "Why do you want to volunteer?") }

  def params_for(first: "Sam", last: "Rivera", email: "sam@example.com", answer: "I care.")
    {
      first_name_field.id.to_s => first,
      last_name_field.id.to_s => last,
      email_field.id.to_s => email,
      question_field.id.to_s => answer
    }
  end

  describe "on-demand training registration" do
    let(:form) { create(:form, slug: "collab-on-demand", published: true, role: "registration") }
    let!(:training) do
      create(:event, :published, facilitator_training: true, on_demand: true,
             title: "On-Demand Facilitator Training", start_date: 2.months.ago, end_date: 10.months.from_now)
    end

    it "registers the person for the current on-demand facilitator training and stamps the event" do
      result = nil
      expect { result = described_class.call(form: form, form_params: params_for) }
        .to change(EventRegistration, :count).by(1)

      registration = EventRegistration.last
      expect(registration.event).to eq(training)
      expect(registration.registrant).to eq(result.person)
      # Invited only after completing the external LMS, so the registration
      # flips straight to attended.
      expect(registration.status).to eq("attended")
      expect(result.form_submission.event).to eq(training)
    end

    it "does not duplicate an existing registration, but flips it to attended" do
      person = create(:person, user: nil, first_name: "Sam", last_name: "Rivera", email: "sam@example.com")
      existing = create(:event_registration, event: training, registrant: person, status: "registered")

      expect { described_class.call(form: form, form_params: params_for) }
        .not_to change(EventRegistration, :count)

      expect(existing.reload.status).to eq("attended")
    end

    it "quietly skips when no current on-demand training exists" do
      training.update!(published: false)

      expect { described_class.call(form: form, form_params: params_for) }
        .not_to change(EventRegistration, :count)
    end

    it "rejects a blank-identity submission rather than recording it anonymously" do
      result = nil
      expect { result = described_class.call(form: form, form_params: params_for(first: "", last: "", email: "")) }
        .to change(FormSubmission, :count).by(0)
        .and change(EventRegistration, :count).by(0)

      expect(result.success?).to be(false)
      expect(result.errors).to include(PublicFormSubmission::IDENTITY_REQUIRED_MESSAGE)
    end

    it "does not register submissions to non-registration forms" do
      plain = create(:form, slug: "plain", published: true)
      field = create(:form_field, form: plain, field_identifier: "first_name")
      last = create(:form_field, form: plain, field_identifier: "last_name")
      email = create(:form_field, form: plain, field_identifier: "primary_email")

      expect {
        described_class.call(form: plain, form_params: { field.id.to_s => "Sam", last.id.to_s => "Rivera", email.id.to_s => "sam@example.com" })
      }.not_to change(EventRegistration, :count)
    end
  end

  it "creates a person, submission, and answers" do
    result = nil
    expect { result = described_class.call(form: form, form_params: params_for) }
      .to change(Person, :count).by(1)
      .and change(FormSubmission, :count).by(1)

    expect(result.success?).to be(true)
    expect(result.person.email).to eq("sam@example.com")
    expect(result.form_submission.role).to eq("public")
    expect(result.form_submission.event).to be_nil

    answer = result.form_submission.form_answers.find_by(form_field: question_field)
    expect(answer.submitted_answer).to eq("I care.")
  end

  it "reuses an existing person matched on email + last name" do
    existing = create(:person, first_name: "Sam", last_name: "Rivera", email: "sam@example.com")

    expect { described_class.call(form: form, form_params: params_for) }
      .to change(Person, :count).by(0)
      .and change(FormSubmission, :count).by(1)

    expect(FormSubmission.last.person).to eq(existing)
  end

  describe "person profile & contact capture (parity with the event registration form)" do
    let!(:pronouns_field)      { create(:form_field, form: form, name: "Pronouns", field_identifier: "pronouns") }
    let!(:pronunciation_field) { create(:form_field, form: form, name: "Name pronunciation", field_identifier: "pronunciation") }
    let!(:nickname_field)      { create(:form_field, form: form, name: "Nickname", field_identifier: "nickname") }
    let!(:email_type_field)    { create(:form_field, form: form, name: "Email type", field_identifier: "primary_email_type") }
    let!(:email_2_field)       { create(:form_field, form: form, name: "Secondary email", field_identifier: "secondary_email") }
    let!(:email_2_type_field)  { create(:form_field, form: form, name: "Secondary email type", field_identifier: "secondary_email_type") }
    let!(:phone_field)         { create(:form_field, form: form, name: "Phone", field_identifier: "phone") }
    let!(:phone_type_field)    { create(:form_field, form: form, name: "Phone type", field_identifier: "phone_type") }
    let!(:street_field)        { create(:form_field, form: form, name: "Street", field_identifier: "mailing_street") }
    let!(:city_field)          { create(:form_field, form: form, name: "City", field_identifier: "mailing_city") }
    let!(:state_field)         { create(:form_field, form: form, name: "State", field_identifier: "mailing_state") }
    let!(:zip_field)           { create(:form_field, form: form, name: "Zip", field_identifier: "mailing_zip") }
    let!(:racial_field)        { create(:form_field, form: form, name: "Identity", field_identifier: "racial_ethnic_identity") }

    def contact_params(overrides = {})
      params_for.merge(
        pronouns_field.id.to_s => "they/them",
        pronunciation_field.id.to_s => "SAM ree-VEH-ra",
        email_type_field.id.to_s => "Work",
        email_2_field.id.to_s => "sam2@example.com",
        email_2_type_field.id.to_s => "Work",
        phone_field.id.to_s => "555-1212",
        phone_type_field.id.to_s => "Work",
        street_field.id.to_s => "1 Main St",
        city_field.id.to_s => "Austin",
        state_field.id.to_s => "TX",
        zip_field.id.to_s => "78701",
        racial_field.id.to_s => "Prefer to self-describe"
      ).merge(overrides)
    end

    it "captures profile and contact fields onto a newly created person" do
      person = described_class.call(form: form, form_params: contact_params).person

      expect(person.pronouns).to eq("they/them")
      expect(person.pronunciation).to eq("SAM ree-VEH-ra")
      expect(person.email_type).to eq("work")
      expect(person.email_2).to eq("sam2@example.com")
      expect(person.email_2_type).to eq("work")
      expect(person.racial_ethnic_identity).to eq("Prefer to self-describe")
      expect(person.phone_number).to eq("555-1212")

      address = person.addresses.find_by(primary: true)
      expect(address.city).to eq("Austin")
      expect(address.street_address).to eq("1 Main St")
    end

    it "overwrites the same fields on an existing matched person, but never on a blank answer" do
      existing = create(:person, first_name: "Sam", last_name: "Rivera", email: "sam@example.com",
                         pronouns: "she/her", email_2: "old@example.com", racial_ethnic_identity: "Kept")

      described_class.call(form: form, form_params: contact_params(racial_field.id.to_s => ""))
      existing.reload

      expect(existing.pronouns).to eq("they/them")
      expect(existing.email_2).to eq("sam2@example.com")
      expect(existing.phone_number).to eq("555-1212")
      expect(existing.racial_ethnic_identity).to eq("Kept")
    end

    it "treats a nickname as the first name and moves the legal name aside" do
      person = described_class.call(form: form, form_params: contact_params(nickname_field.id.to_s => "Sammy")).person

      expect(person.first_name).to eq("Sammy")
      expect(person.legal_first_name).to eq("Sam")
    end
  end

  describe "organization capture (parity with the event registration form)" do
    let!(:org) { create(:organization, name: "Helping Hands") }
    let!(:org_name_field)     { create(:form_field, form: form, name: "Organization", field_identifier: "organization_name") }
    let!(:org_position_field) { create(:form_field, form: form, name: "Position", field_identifier: "organization_position") }
    let!(:org_website_field)  { create(:form_field, form: form, name: "Website", field_identifier: "organization_website") }
    let!(:org_type_field)     { create(:form_field, form: form, name: "Type", field_identifier: "organization_type") }
    let!(:org_city_field)     { create(:form_field, form: form, name: "Org city", field_identifier: "organization_city") }
    let!(:org_state_field)    { create(:form_field, form: form, name: "Org state", field_identifier: "organization_state") }

    def org_params(overrides = {})
      params_for.merge(
        org_name_field.id.to_s => "Helping Hands",
        org_position_field.id.to_s => "Counselor",
        org_website_field.id.to_s => "https://helpinghands.org",
        org_type_field.id.to_s => "Nonprofit",
        org_city_field.id.to_s => "Austin",
        org_state_field.id.to_s => "TX"
      ).merge(overrides)
    end

    it "matches the org by name, syncs its profile and address, adds a job affiliation, and links it to the submission" do
      result = described_class.call(form: form, form_params: org_params)
      org.reload

      expect(org.website_url).to eq("https://helpinghands.org")
      expect(org.organization_type).to eq("Nonprofit")
      expect(org.addresses.find_by(city: "Austin")).to be_present
      expect(result.person.affiliations.where(organization: org).pluck(:title)).to contain_exactly("Counselor")
      expect(result.form_submission.reload.linked_organizations).to include(org)
    end

    it "never creates an organization from an unmatched name — it's left for an admin" do
      expect {
        described_class.call(form: form, form_params: org_params(org_name_field.id.to_s => "Ghost Org"))
      }.not_to change(Organization, :count)
    end

    it "does not mint a facilitator affiliation on an ordinary standalone form" do
      result = described_class.call(form: form, form_params: org_params)

      expect(result.person.affiliations.where(organization: org).pluck(:title)).not_to include("Facilitator")
    end

    it "mints both a job and a facilitator affiliation on a new-job agreement form" do
      form.update!(role: "new_job")

      result = described_class.call(form: form, form_params: org_params)

      expect(result.person.affiliations.where(organization: org).pluck(:title))
        .to contain_exactly("Counselor", "Facilitator")
    end
  end

  it "sends a confirmation to the submitter and an FYI to admin" do
    expect { described_class.call(form: form, form_params: params_for) }
      .to change { Notification.where(kind: "form_submission_confirmation").count }.by(1)
      .and change { Notification.where(kind: "form_submission_confirmation_fyi").count }.by(1)

    confirmation = Notification.find_by(kind: "form_submission_confirmation")
    expect(confirmation.recipient_email).to eq("sam@example.com")
    expect(confirmation.recipient_role).to eq("person")
  end

  context "when identity is left blank (optional name/email questions)" do
    it "records a person-less submission when identity is blank" do
      result = nil
      expect { result = described_class.call(form: form, form_params: params_for(first: "", last: "", email: "")) }
        .to change(FormSubmission, :count).by(1)
        .and change(Person, :count).by(0)

      expect(result.success?).to be(true)
      expect(result.form_submission.person).to be_nil
      expect(result.form_submission).to be_anonymous
      expect(result.form_submission.form_answers.find_by(form_field: question_field).submitted_answer).to eq("I care.")
    end

    it "still builds a person when the respondent chooses to identify" do
      result = nil
      expect { result = described_class.call(form: form, form_params: params_for) }
        .to change(Person, :count).by(1)

      expect(result.form_submission.person.email).to eq("sam@example.com")
    end

    it "skips the submitter confirmation but still sends the admin FYI for an anonymous submission" do
      expect { described_class.call(form: form, form_params: params_for(first: "", last: "", email: "")) }
        .to change { Notification.where(kind: "form_submission_confirmation").count }.by(0)
        .and change { Notification.where(kind: "form_submission_confirmation_fyi").count }.by(1)
    end
  end

  it "subscribes the submitter to News, sourced to the form, when the consent question is answered" do
    news = create(:topic_subscription_type, name: "News")
    consent_field = create(:form_field, form: form, name: "Email me updates",
                           answer_type: :multi_select_checkbox, field_identifier: "communication_consent")
    params = params_for.merge(consent_field.id.to_s => [ "Yes, keep me posted" ])

    result = described_class.call(form: form, form_params: params)

    subscription = result.person.topic_subscriptions.active.for_topic_type(news).sole
    expect(subscription.source).to include(form.display_name)
  end

  it "saves a quote-field answer as an unpublished quote sourced from the submission" do
    quote_field = create(:form_field, form: form, name: "Share a quote", field_identifier: "quote")
    params = params_for.merge(quote_field.id.to_s => "This place changed my life")

    expect { described_class.call(form: form, form_params: params) }.to change(Quote, :count).by(1)

    submission = FormSubmission.last
    quote = submission.quotes.sole
    expect(quote.body).to eq("This place changed my life")
    expect(quote).not_to be_published
    expect(quote.author_credit).to eq("Anonymous")
  end

  it "captures a sector 'Other' answer as an OtherResponse, like the other submission paths" do
    sector_field = create(:form_field, form: form, name: "Who do you serve?",
                          answer_type: :multi_select_checkbox, field_identifier: "additional_sectors")
    params = params_for.merge(sector_field.id.to_s => [ "Other: Equine therapy" ])

    result = described_class.call(form: form, form_params: params)

    response = result.person.other_responses.sole
    expect([ response.field_identifier, response.text, response.kind ])
      .to eq([ "additional_sectors", "Equine therapy", "sector" ])
  end

  describe "close-program processing" do
    let(:form) { create(:form, slug: "close-program", published: true, role: "close_program") }
    let!(:org_field) { create(:form_field, form: form, name: "Organization name", field_identifier: "organization_name") }
    let!(:date_field) { create(:form_field, form: form, name: "As of what date?", field_identifier: "close_effective_date") }
    let!(:reason_field) { create(:form_field, form: form, name: "Why?", field_identifier: "close_reason") }
    let!(:leaving_field) { create(:form_field, form: form, name: "Leaving your job?", field_identifier: "close_leaving_job") }

    let(:organization) { create(:organization, name: "Sunset Youth Services") }

    def close_params(org_name: "Sunset Youth Services", date: "2026-06-30", reason: "Funding ended.", leaving: "No")
      {
        first_name_field.id.to_s => "Casey",
        last_name_field.id.to_s => "Closing",
        email_field.id.to_s => "casey@example.com",
        org_field.id.to_s => org_name,
        date_field.id.to_s => date,
        reason_field.id.to_s => reason,
        leaving_field.id.to_s => leaving
      }
    end

    it "end-dates the person's facilitator affiliation at the exact-match org and links it" do
      person = create(:person, user: nil, first_name: "Casey", last_name: "Closing", email: "casey@example.com")
      facilitator = create(:affiliation, person: person, organization: organization, title: "Facilitator")

      result = described_class.call(form: form, form_params: close_params)

      expect(facilitator.reload.end_date).to eq(Date.new(2026, 6, 30))
      expect(facilitator.comments.last.topic).to eq("Program closure")
      expect(result.form_submission.linked_organization_ids).to include(organization.id)
      expect(result.form_submission.scenario_ended_affiliation_ids).to include(facilitator.id)
    end

    it "also ends the job affiliation when they say they're leaving" do
      person = create(:person, user: nil, first_name: "Casey", last_name: "Closing", email: "casey@example.com")
      facilitator = create(:affiliation, person: person, organization: organization, title: "Facilitator")
      job = create(:affiliation, person: person, organization: organization, title: "Program Director")

      described_class.call(form: form, form_params: close_params(leaving: "Yes"))

      expect(facilitator.reload.end_date).to eq(Date.new(2026, 6, 30))
      expect(job.reload.end_date).to eq(Date.new(2026, 6, 30))
    end

    it "does not auto-process when the org name has no exact match — it waits for the panel" do
      person = create(:person, user: nil, first_name: "Casey", last_name: "Closing", email: "casey@example.com")
      facilitator = create(:affiliation, person: person, organization: organization, title: "Facilitator")

      result = described_class.call(form: form, form_params: close_params(org_name: "Sunset Youth"))

      expect(facilitator.reload.end_date).to be_nil
      expect(result.form_submission.linked_organization_ids).to be_empty
    end

    it "does not auto-process when two organizations share the submitted name" do
      create(:organization, name: "Sunset Youth Services")
      person = create(:person, user: nil, first_name: "Casey", last_name: "Closing", email: "casey@example.com")
      facilitator = create(:affiliation, person: person, organization: organization, title: "Facilitator")

      described_class.call(form: form, form_params: close_params)

      expect(facilitator.reload.end_date).to be_nil
    end
  end
end
