require "rails_helper"

RSpec.describe EventRegistrationServices::PublicRegistration do
  let(:event) { create(:event, :published, :publicly_visible) }
  let(:form) do
    f = FormBuilderService.new(
      name: "Extended Event Registration",
      sections: %i[person_identifier person_contact_info person_background professional_info marketing scholarship payment consent]
    ).call
    event.event_forms.create!(form: f, role: "registration")
    f
  end

  def field_id(key)
    form.form_fields.find_by!(field_identifier: key).id.to_s
  end

  def base_form_params(first_name:, last_name:, email:)
    {
      field_id("first_name") => first_name,
      field_id("last_name") => last_name,
      field_id("primary_email") => email,
      field_id("primary_email_type") => "personal"
    }
  end

  describe "affiliation creation" do
    let!(:organization) { create(:organization, name: "Helping Hands") }

    def register_with(position:)
      params = base_form_params(first_name: "Sam", last_name: "Rowe", email: "sam@example.com").merge(
        field_id(described_class::ORGANIZATION_NAME_IDENTIFIER) => "Helping Hands"
      )
      params[field_id(described_class::ORGANIZATION_POSITION_IDENTIFIER)] = position if position
      described_class.call(event: event, registration_form: form, form_params: params)
      Person.find_by(email: "sam@example.com")
    end

    it "creates a job affiliation and a facilitator affiliation from the typed position" do
      person = register_with(position: "Counselor")

      expect(person.affiliations.where(organization: organization).pluck(:title))
        .to contain_exactly("Counselor", "Facilitator")
    end

    it "creates only a facilitator affiliation when no position was typed" do
      person = register_with(position: nil)

      expect(person.affiliations.where(organization: organization).pluck(:title))
        .to contain_exactly("Facilitator")
    end

    it "links the created affiliations to the agency address built from the form" do
      params = base_form_params(first_name: "Sam", last_name: "Rowe", email: "sam@example.com").merge(
        field_id(described_class::ORGANIZATION_NAME_IDENTIFIER) => "Helping Hands",
        field_id(described_class::ORGANIZATION_POSITION_IDENTIFIER) => "Counselor",
        field_id("agency_street") => "1 Main St",
        field_id("agency_city") => "Austin",
        field_id("agency_state") => "TX",
        field_id("agency_zip") => "78701",
        field_id("agency_country") => "USA"
      )
      described_class.call(event: event, registration_form: form, form_params: params)
      person = Person.find_by(email: "sam@example.com")

      address = organization.addresses.find_by(city: "Austin")
      expect(address).to be_present
      expect(address.country).to eq("USA")
      linked = person.affiliations.where(organization: organization)
      expect(linked.pluck(:title)).to contain_exactly("Counselor", "Facilitator")
      expect(linked.map(&:organization_address)).to all(eq(address))
    end

    it "leaves the affiliations' organization address nil when no agency city was typed" do
      person = register_with(position: "Counselor")

      expect(person.affiliations.where(organization: organization).map(&:organization_address)).to all(be_nil)
    end
  end

  describe "registration organizations" do
    let!(:organization) { create(:organization, name: "Helping Hands") }

    def register_with_org(org_name)
      params = base_form_params(first_name: "Sam", last_name: "Rowe", email: "sam@example.com").merge(
        field_id(described_class::ORGANIZATION_NAME_IDENTIFIER) => org_name
      )
      described_class.call(event: event, registration_form: form, form_params: params)
      event.event_registrations.find_by!(registrant: Person.find_by(email: "sam@example.com"))
    end

    it "connects only the organization submitted through the form" do
      registration = register_with_org("Helping Hands")

      expect(registration.organizations).to contain_exactly(organization)
    end

    it "does not connect the registrant's other active affiliations" do
      person = create(:person, email: "sam@example.com", last_name: "Rowe", first_name: "Sam")
      other_org = create(:organization, name: "Unrelated Org")
      create(:affiliation, person: person, organization: other_org)

      registration = register_with_org("Helping Hands")

      expect(registration.organizations).to contain_exactly(organization)
    end

    it "connects no organizations when none is submitted" do
      params = base_form_params(first_name: "Sam", last_name: "Rowe", email: "sam@example.com")
      described_class.call(event: event, registration_form: form, form_params: params)
      registration = event.event_registrations.find_by!(registrant: Person.find_by(email: "sam@example.com"))

      expect(registration.organizations).to be_empty
    end

    it "adds the new org to the same registration when the registrant applies again" do
      second_org = create(:organization, name: "Second Org")
      first = register_with_org("Helping Hands")
      second = register_with_org("Second Org")

      expect(second).to eq(first)
      expect(first.organizations).to contain_exactly(organization, second_org)
    end
  end

  describe "racial/ethnic identity" do
    it "stores the racial/ethnic identity on a new registrant" do
      params = base_form_params(first_name: "Ada", last_name: "Lin", email: "ada@example.com").merge(
        field_id("racial_ethnic_identity") => "Asian"
      )

      described_class.call(event: event, registration_form: form, form_params: params)

      expect(Person.find_by!(email: "ada@example.com").racial_ethnic_identity).to eq("Asian")
    end

    it "overwrites a racial/ethnic identity already on file with the latest answer" do
      existing = create(:person, first_name: "Ada", last_name: "Lin",
                                 email: "ada@example.com", racial_ethnic_identity: "Multi-racial")
      params = base_form_params(first_name: "Ada", last_name: "Lin", email: "ada@example.com").merge(
        field_id("racial_ethnic_identity") => "Asian"
      )

      described_class.call(event: event, registration_form: form, form_params: params)

      expect(existing.reload.racial_ethnic_identity).to eq("Asian")
    end

    it "leaves a racial/ethnic identity on file untouched when the answer is blank" do
      existing = create(:person, first_name: "Ada", last_name: "Lin",
                                 email: "ada@example.com", racial_ethnic_identity: "Multi-racial")
      params = base_form_params(first_name: "Ada", last_name: "Lin", email: "ada@example.com").merge(
        field_id("racial_ethnic_identity") => ""
      )

      described_class.call(event: event, registration_form: form, form_params: params)

      expect(existing.reload.racial_ethnic_identity).to eq("Multi-racial")
    end
  end

  describe "expected payment method" do
    it "records the chosen payment method on a new registration" do
      params = base_form_params(first_name: "Pat", last_name: "Doe", email: "pat@example.com").merge(
        field_id("payment_method") => "Check"
      )

      described_class.call(event: event, registration_form: form, form_params: params)

      expect(EventRegistration.last.expected_payment_method).to eq("Check")
    end

    it "updates the expected payment method when an existing registrant re-registers" do
      person = create(:person, first_name: "Pat", last_name: "Doe", email: "pat@example.com")
      create(:event_registration, event: event, registrant: person, expected_payment_method: "Check")
      params = base_form_params(first_name: "Pat", last_name: "Doe", email: "pat@example.com").merge(
        field_id("payment_method") => "Credit card (now)"
      )

      described_class.call(event: event, registration_form: form, form_params: params)

      expect(event.event_registrations.find_by(registrant: person).expected_payment_method).to eq("Credit card (now)")
    end
  end

  describe "mailing list consent" do
    it "stamps the consent time and source when the registrant opts in" do
      params = base_form_params(first_name: "Coco", last_name: "Lee", email: "coco@example.com").merge(
        field_id("communication_consent") => [ "Yes" ]
      )

      described_class.call(event: event, registration_form: form, form_params: params)
      person = Person.find_by!(email: "coco@example.com")

      expect(person.mailing_list_consent_at).to be_present
      expect(person.mailing_list_consent_source).to eq("#{event.start_date.to_date.iso8601} #{event.title} registration")
    end

    it "does not record consent when the box is left unchecked" do
      params = base_form_params(first_name: "Coco", last_name: "Lee", email: "coco@example.com").merge(
        field_id("communication_consent") => [ "" ]
      )

      described_class.call(event: event, registration_form: form, form_params: params)

      expect(Person.find_by!(email: "coco@example.com").mailing_list_consent_at).to be_nil
    end

    it "never re-stamps or clears consent already on file" do
      original = 1.year.ago
      create(:person, first_name: "Coco", last_name: "Lee", email: "coco@example.com",
                      mailing_list_consent_at: original, mailing_list_consent_source: "Earlier")
      params = base_form_params(first_name: "Coco", last_name: "Lee", email: "coco@example.com").merge(
        field_id("communication_consent") => [ "Yes" ]
      )

      described_class.call(event: event, registration_form: form, form_params: params)
      person = Person.find_by!(email: "coco@example.com")

      expect(person.mailing_list_consent_at).to be_within(1.second).of(original)
      expect(person.mailing_list_consent_source).to eq("Earlier")
    end
  end

  describe "structured contact and organization data" do
    it "stores the mailing country on a new registrant's address" do
      params = base_form_params(first_name: "Ada", last_name: "Lin", email: "ada@example.com").merge(
        field_id("mailing_street") => "1 Main St",
        field_id("mailing_city") => "Oakland",
        field_id("mailing_state") => "CA",
        field_id("mailing_zip") => "94601",
        field_id("mailing_country") => "USA"
      )

      described_class.call(event: event, registration_form: form, form_params: params)
      person = Person.find_by!(email: "ada@example.com")

      expect(person.addresses.find_by(primary: true).country).to eq("USA")
    end

    context "with a matched organization" do
      let!(:organization) { create(:organization, name: "Helping Hands") }

      def register_with_org(extra)
        params = base_form_params(first_name: "Sam", last_name: "Rowe", email: "sam@example.com").merge(
          field_id(described_class::ORGANIZATION_NAME_IDENTIFIER) => "Helping Hands"
        ).merge(extra)
        described_class.call(event: event, registration_form: form, form_params: params)
      end

      it "fills website, agency type, and address country" do
        register_with_org(
          field_id("agency_website") => "helpinghands.org",
          field_id("agency_type") => "501c3/nonprofit",
          field_id("agency_street") => "5 Oak Ave",
          field_id("agency_city") => "Reno",
          field_id("agency_state") => "NV",
          field_id("agency_zip") => "89501",
          field_id("agency_country") => "USA"
        )
        organization.reload

        expect(organization.agency_type).to eq("501c3/nonprofit")
        expect(organization.website_url).to include("helpinghands.org")
        expect(organization.addresses.find_by(primary: true).country).to eq("USA")
      end

      it "overwrites an existing website with the latest answer" do
        organization.update!(website_url: "https://existing.org")

        register_with_org(field_id("agency_website") => "helpinghands.org")

        expect(organization.reload.website_url).to include("helpinghands.org")
      end

      it "stores the org address as a work address" do
        register_with_org(
          field_id("agency_street") => "5 Oak Ave",
          field_id("agency_city") => "Reno",
          field_id("agency_state") => "NV",
          field_id("agency_zip") => "89501"
        )

        expect(organization.addresses.last.address_type).to eq("work")
      end

      it "makes the first org address primary" do
        register_with_org(
          field_id("agency_street") => "5 Oak Ave",
          field_id("agency_city") => "Reno",
          field_id("agency_state") => "NV",
          field_id("agency_zip") => "89501"
        )

        expect(organization.addresses.find_by(city: "Reno")).to be_primary
      end

      it "does not demote the org's existing primary when another registrant adds an address" do
        existing = organization.addresses.create!(
          street_address: "1 First St", city: "Tahoe", state: "CA", zip_code: "96150",
          locality: "Unknown", address_type: "work", primary: true
        )

        register_with_org(
          field_id("agency_street") => "5 Oak Ave",
          field_id("agency_city") => "Reno",
          field_id("agency_state") => "NV",
          field_id("agency_zip") => "89501"
        )

        expect(existing.reload).to be_primary
        expect(existing).not_to be_inactive
        expect(organization.addresses.find_by(city: "Reno")).not_to be_primary
      end
    end
  end

  describe "organization type sync" do
    let!(:organization) { create(:organization, name: "Helping Hands") }

    def register_with_agency_type(value)
      params = base_form_params(first_name: "Sam", last_name: "Rowe", email: "sam@example.com").merge(
        field_id(described_class::ORGANIZATION_NAME_IDENTIFIER) => "Helping Hands",
        field_id("agency_type") => value
      )
      described_class.call(event: event, registration_form: form, form_params: params)
      organization.reload
    end

    it "folds an 'Other' answer into agency_type and the stripped free text into agency_type_other" do
      register_with_agency_type("Other: Equine therapy")

      expect(organization.agency_type).to eq("Other")
      expect(organization.agency_type_other).to eq("Equine therapy")
    end

    it "stores the answer as 'Other: <text>' on the form submission, like other specify options" do
      register_with_agency_type("Other: Equine therapy")

      answer = FormAnswer.joins(:form_field)
        .find_by(form_fields: { field_identifier: "agency_type" })
      expect(answer.submitted_answer).to eq("Other: Equine therapy")
    end

    it "stores a non-'Other' classification with no agency_type_other" do
      register_with_agency_type("501c3/nonprofit")

      expect(organization.agency_type).to eq("501c3/nonprofit")
      expect(organization.agency_type_other).to be_nil
    end

    it "overwrites a previously stored type with the latest registrant's answer" do
      organization.update!(agency_type: "501c3/nonprofit", agency_type_other: nil)

      register_with_agency_type("Other: Equine therapy")

      expect(organization.agency_type).to eq("Other")
      expect(organization.agency_type_other).to eq("Equine therapy")
    end

    it "clears a stale agency_type_other when the latest answer is no longer 'Other'" do
      organization.update!(agency_type: "Other", agency_type_other: "Equine therapy")

      register_with_agency_type("Government agency")

      expect(organization.agency_type).to eq("Government agency")
      expect(organization.agency_type_other).to be_nil
    end
  end

  describe "matching an existing registrant by name" do
    it "matches a person stored under a nickname when the registrant types their legal first name" do
      existing = create(:person, first_name: "Bob", legal_first_name: "Robert",
                                 last_name: "Smith", email: "bob@example.com")

      params = base_form_params(first_name: "Robert", last_name: "Smith", email: "bob@example.com")

      expect {
        described_class.call(event: event, registration_form: form, form_params: params)
      }.not_to change(Person, :count)

      expect(EventRegistration.last.registrant).to eq(existing)
    end

    it "matches a person stored under a legal name when the registrant types their nickname" do
      existing = create(:person, first_name: "Robert", legal_first_name: nil,
                                 last_name: "Smith", email: "bob@example.com")

      params = base_form_params(first_name: "Robert", last_name: "Smith", email: "bob@example.com").merge(
        field_id("nickname") => "Bob"
      )

      expect {
        described_class.call(event: event, registration_form: form, form_params: params)
      }.not_to change(Person, :count)

      expect(EventRegistration.last.registrant).to eq(existing)
    end

    it "still creates a new person when the email matches but it is a different name" do
      create(:person, first_name: "Bob", last_name: "Smith", email: "shared@example.com")

      params = base_form_params(first_name: "Dana", last_name: "Jones", email: "shared@example.com")

      expect {
        described_class.call(event: event, registration_form: form, form_params: params)
      }.to change(Person, :count).by(1)
    end
  end

  describe "an answer longer than its database column" do
    # `city` (like the other mapped person/address columns) is a varchar(255).
    # A longer answer must surface as a form error, not an ActiveRecord::ValueTooLong
    # 500 that escapes the registration flow.
    let(:params) do
      base_form_params(first_name: "Pat", last_name: "Lee", email: "pat@example.com").merge(
        field_id("mailing_street") => "1 Main St",
        field_id("mailing_city") => "a" * 256,
        field_id("mailing_state") => "CA",
        field_id("mailing_zip") => "90001"
      )
    end

    it "returns a failed result instead of raising" do
      result = nil
      expect {
        result = described_class.call(event: event, registration_form: form, form_params: params)
      }.not_to raise_error

      expect(result.success?).to be false
      expect(result.errors.join).to match(/city.*too long/i)
    end

    it "does not create a registration" do
      expect {
        described_class.call(event: event, registration_form: form, form_params: params)
      }.not_to change(EventRegistration, :count)
    end
  end

  describe "sector tagging" do
    let!(:primary_sector) { create(:sector, name: "Healthcare") }
    let!(:additional_sector) { create(:sector, name: "Education") }

    it "marks the dropdown answer primary and the checkbox answers additional" do
      result = described_class.call(
        event: event,
        registration_form: form,
        form_params: base_form_params(first_name: "Pat", last_name: "Lee", email: "pat@example.com").merge(
          field_id("primary_sector_single") => primary_sector.id.to_s,
          field_id("additional_sectors") => [ additional_sector.id.to_s ]
        )
      )

      expect(result.success?).to be true
      person = result.event_registration.registrant
      expect(person.sectorable_items.find_by(sector: primary_sector).is_primary).to be true
      expect(person.sectorable_items.find_by(sector: additional_sector).is_primary).to be false
    end

    it "promotes an existing additional sector when later named as primary" do
      person = create(:person, first_name: "Pat", last_name: "Lee", email: "pat@example.com")
      person.sectorable_items.create!(sector: primary_sector, is_primary: false)

      described_class.call(
        event: event,
        registration_form: form,
        form_params: base_form_params(first_name: "Pat", last_name: "Lee", email: "pat@example.com").merge(
          field_id("primary_sector_single") => primary_sector.id.to_s
        )
      )

      expect(person.sectorable_items.find_by(sector: primary_sector).is_primary).to be true
    end

    it "demotes a prior primary that the registrant did not re-select as primary" do
      person = create(:person, first_name: "Pat", last_name: "Lee", email: "pat@example.com")
      person.sectorable_items.create!(sector: additional_sector, is_primary: true)

      described_class.call(
        event: event,
        registration_form: form,
        form_params: base_form_params(first_name: "Pat", last_name: "Lee", email: "pat@example.com").merge(
          field_id("primary_sector_single") => primary_sector.id.to_s
        )
      )

      person.reload
      expect(person.sectorable_items.find_by(sector: primary_sector).is_primary).to be true
      expect(person.sectorable_items.find_by(sector: additional_sector).is_primary).to be false
    end
  end

  describe "age group tagging" do
    let(:age_type) { create(:category_type, name: "AgeRange", published: true) }
    let!(:young) { create(:category, :published, category_type: age_type, name: "3-5") }
    let!(:teen) { create(:category, :published, category_type: age_type, name: "13-17") }

    it "tags primary and additional age groups on the registrant" do
      result = described_class.call(
        event: event,
        registration_form: form,
        form_params: base_form_params(first_name: "Al", last_name: "Ng", email: "al@example.com").merge(
          field_id("primary_age_group") => [ young.id.to_s ],
          field_id("additional_age_group") => [ teen.id.to_s ]
        )
      )

      expect(result.success?).to be true
      person = result.event_registration.registrant
      expect(person.primary_age_groups).to contain_exactly(young)
      expect(person.additional_age_groups).to contain_exactly(teen)
    end
  end

  describe "CE credit interest (magic question)" do
    let!(:ce_field) do
      field = form.form_fields.create!(
        name: "Might you be seeking continuing education (CE) hours for attending this training?",
        answer_type: :single_select_radio,
        status: :active,
        position: (form.form_fields.maximum(:position) || 0) + 1,
        required: false,
        field_identifier: described_class::CE_CREDIT_INTEREST_IDENTIFIER,
        section: "continuing_education",
        visibility: :always_ask
      )
      %w[Yes No].each_with_index do |opt, idx|
        ao = AnswerOption.find_or_create_by!(name: opt) { |a| a.position = idx }
        field.form_field_answer_options.create!(answer_option: ao)
      end
      field
    end

    let!(:ce_license_field) do
      form.form_fields.create!(
        name: "License number",
        answer_type: :free_form_input_one_line,
        status: :active,
        position: (form.form_fields.maximum(:position) || 0) + 1,
        required: false,
        field_identifier: described_class::CE_LICENSE_NUMBER_IDENTIFIER,
        section: "continuing_education",
        visibility: :always_ask
      )
    end

    def register_with_ce(answer, license: nil)
      params = base_form_params(first_name: "Cy", last_name: "Reed", email: "cy@example.com")
      params = params.merge(ce_field.id.to_s => answer) unless answer.nil?
      params = params.merge(ce_license_field.id.to_s => license) if license
      described_class.call(event: event, registration_form: form, form_params: params)
    end

    it "creates a CE registration when answered Yes" do
      result = register_with_ce("Yes")
      expect(result.event_registration.continuing_education_registrations.count).to eq(1)
    end

    it "creates no CE registration when answered No" do
      result = register_with_ce("No")
      expect(result.event_registration.continuing_education_registrations).to be_empty
    end

    it "creates no CE registration when unanswered" do
      result = register_with_ce(nil)
      expect(result.event_registration.continuing_education_registrations).to be_empty
    end

    it "creates a CE registration for an existing registration that answers Yes" do
      person = create(:person, first_name: "Cy", last_name: "Reed", email: "cy@example.com")
      existing = create(:event_registration, event: event, registrant: person)

      result = register_with_ce("Yes")

      expect(result.event_registration).to eq(existing)
      expect(existing.reload.continuing_education_registrations.count).to eq(1)
    end

    it "records the typed license number on the CE registration's license" do
      result = register_with_ce("Yes", license: "LMFT 555")
      license = result.event_registration.continuing_education_registrations.first.professional_license
      expect(license.number).to eq("LMFT 555")
      expect(license.person).to eq(result.event_registration.registrant)
    end

    it "uses a placeholder license when no number is given" do
      result = register_with_ce("Yes")
      expect(result.event_registration.continuing_education_registrations.first.professional_license.number).to be_nil
    end

    it "takes the CE hours from the event" do
      event.update!(ce_hours_offered: 6)
      result = register_with_ce("Yes")
      expect(result.event_registration.continuing_education_registrations.first.hours).to eq(6)
    end
  end

  describe "Additional forms (multi-select magic question)" do
    let!(:additional_forms_field) do
      field = form.form_fields.create!(
        name: "Do you need either of the following?",
        answer_type: :multi_select_checkbox,
        status: :active,
        position: (form.form_fields.maximum(:position) || 0) + 1,
        required: false,
        field_identifier: described_class::ADDITIONAL_FORMS_IDENTIFIER,
        section: "additional_forms",
        visibility: :always_ask
      )
      [ described_class::ADDITIONAL_FORMS_INVOICE, described_class::ADDITIONAL_FORMS_W9 ].each_with_index do |opt, idx|
        ao = AnswerOption.find_or_create_by!(name: opt) { |a| a.position = idx }
        field.form_field_answer_options.create!(answer_option: ao)
      end
      field
    end

    def register_with_additional_forms(selections)
      params = base_form_params(first_name: "Wendy", last_name: "Nein", email: "wendy@example.com")
      params = params.merge(additional_forms_field.id.to_s => selections) unless selections.nil?
      described_class.call(event: event, registration_form: form, form_params: params)
    end

    it "sets both flags when both options are checked" do
      registration = register_with_additional_forms([ "Invoice", "W-9" ]).event_registration
      expect(registration.invoice_requested).to be true
      expect(registration.w9_requested).to be true
    end

    it "sets only w9_requested when only W-9 is checked" do
      registration = register_with_additional_forms([ "W-9" ]).event_registration
      expect(registration.w9_requested).to be true
      expect(registration.invoice_requested).to be false
    end

    it "sets only invoice_requested when only Invoice is checked" do
      registration = register_with_additional_forms([ "Invoice" ]).event_registration
      expect(registration.invoice_requested).to be true
      expect(registration.w9_requested).to be false
    end

    it "leaves both flags off when nothing is checked" do
      registration = register_with_additional_forms(nil).event_registration
      expect(registration.w9_requested).to be false
      expect(registration.invoice_requested).to be false
    end

    it "turns the flags on for an existing registration that now checks the options" do
      person = create(:person, first_name: "Wendy", last_name: "Nein", email: "wendy@example.com")
      existing = create(:event_registration, event: event, registrant: person,
                                              w9_requested: false, invoice_requested: false)

      result = register_with_additional_forms([ "Invoice", "W-9" ])

      expect(result.event_registration).to eq(existing)
      expect(existing.reload.w9_requested).to be true
      expect(existing.reload.invoice_requested).to be true
    end
  end

  describe "re-registration after cancellation" do
    let(:person) { create(:person, first_name: "Jane", last_name: "Doe", email: "jane@example.com") }
    let!(:cancelled_registration) do
      create(:event_registration, event: event, registrant: person, status: "cancelled")
    end

    it "reactivates a cancelled registration" do
      result = described_class.call(
        event: event,
        registration_form: form,
        form_params: base_form_params(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
      )

      expect(result.success?).to be true
      expect(result.event_registration).to eq(cancelled_registration)
      expect(cancelled_registration.reload.status).to eq("registered")
    end

    it "sends confirmation and FYI notifications on re-registration" do
      expect(NotificationServices::CreateNotification).to receive(:call).with(
        hash_including(kind: :event_registration_confirmation, recipient_role: :person)
      )
      expect(NotificationServices::CreateNotification).to receive(:call).with(
        hash_including(kind: :event_registration_confirmation_fyi, recipient_role: :admin)
      )

      described_class.call(
        event: event,
        registration_form: form,
        form_params: base_form_params(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
      )
    end

    it "does not send notifications for an already-active registration" do
      cancelled_registration.update!(status: "registered")

      expect(NotificationServices::CreateNotification).not_to receive(:call)

      described_class.call(
        event: event,
        registration_form: form,
        form_params: base_form_params(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
      )
    end
  end

  describe "saving an \"Other\" answer with custom text" do
    let!(:radio_field) do
      field = form.form_fields.create!(
        name: "How did you hear about us?",
        answer_type: :single_select_radio,
        status: :active,
        position: (form.form_fields.maximum(:position) || 0) + 1,
        required: false
      )
      %w[Email Other].each_with_index do |opt, idx|
        ao = AnswerOption.find_or_create_by!(name: opt) { |a| a.position = idx }
        field.form_field_answer_options.create!(answer_option: ao)
      end
      field
    end

    it "stores the folded \"Other: <text>\" value from a radio field" do
      result = described_class.call(
        event: event,
        registration_form: form,
        form_params: base_form_params(first_name: "Jo", last_name: "Vo", email: "jo@example.com").merge(
          radio_field.id.to_s => "Other: a friend told me"
        )
      )

      answer = result.form_submission.form_answers.find_by(form_field: radio_field)
      expect(answer.submitted_answer).to eq("Other: a friend told me")
    end

    it "stores the folded \"Other: <text>\" value alongside other checkbox selections" do
      multi_field = form.form_fields.create!(
        name: "Which topics interest you?",
        answer_type: :multi_select_checkbox,
        status: :active,
        position: (form.form_fields.maximum(:position) || 0) + 1,
        required: false
      )

      result = described_class.call(
        event: event,
        registration_form: form,
        form_params: base_form_params(first_name: "Mo", last_name: "Vo", email: "mo@example.com").merge(
          multi_field.id.to_s => [ "Healing", "Other: poetry therapy" ]
        )
      )

      answer = result.form_submission.form_answers.find_by(form_field: multi_field)
      expect(answer.submitted_answer).to eq("Healing, Other: poetry therapy")
    end
  end

  describe "separate scholarship form submission" do
    let(:scholarship_form) do
      f = create(:form, role: "scholarship")
      event.event_forms.create!(form: f, role: "scholarship")
      f
    end
    let!(:scholarship_field) do
      create(:form_field, form: scholarship_form, answer_type: :free_form_input_paragraph,
             name: "Describe your need", required: false)
    end

    it "persists the scholarship answers as a scholarship-role submission tied to the event" do
      result = described_class.call(
        event: event,
        registration_form: form,
        form_params: base_form_params(first_name: "Sky", last_name: "Need", email: "sky@example.com"),
        scholarship_requested: true,
        scholarship_form: scholarship_form,
        scholarship_params: { scholarship_field.id.to_s => "Our training budget was cut this year." }
      )

      expect(result.success?).to be true
      person = result.event_registration.registrant
      submission = FormSubmission.find_by(person: person, form: scholarship_form, role: "scholarship")
      expect(submission).to be_present
      expect(submission.event).to eq(event)
      expect(submission.form_answers.find_by(form_field: scholarship_field).submitted_answer)
        .to eq("Our training budget was cut this year.")
    end

    it "does not create a scholarship submission when no scholarship was requested" do
      result = described_class.call(
        event: event,
        registration_form: form,
        form_params: base_form_params(first_name: "Plain", last_name: "Reg", email: "plain@example.com")
      )

      person = result.event_registration.registrant
      expect(FormSubmission.where(person: person, role: "scholarship")).to be_empty
    end
  end
end
