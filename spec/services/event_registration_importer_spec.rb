require "rails_helper"

RSpec.describe EventRegistrationImporter do
  let(:event) { create(:event, facilitator_training: true) }
  let(:csv_path) { Rails.root.join("spec/fixtures/files/event_registrants_import.csv").to_s }

  before do
    create(:organization, name: "Sample Org")
    build_registration_form(event)
  end

  def build_registration_form(event)
    form = create(:form, name: "Registration form")
    create(:event_form, event: event, form: form, role: "registration")
    %w[first_name last_name primary_email organization_name].each do |identifier|
      create(:form_field, form: form, field_identifier: identifier)
    end
    form
  end

  def import(dry_run:)
    described_class.call(file_path: csv_path, event: event, dry_run: dry_run)
  end

  describe ".importable?" do
    it "is true once the event has a registration form with an org field" do
      expect(described_class.importable?(event)).to be(true)
    end

    it "is false for an event without a registration form" do
      expect(described_class.importable?(create(:event))).to be(false)
    end
  end

  describe "counting (dry run)" do
    subject(:result) { import(dry_run: true) }

    it "processes every non-blank row" do
      expect(result.rows_processed).to eq(5)
    end

    it "counts a would-be-created person for each unmatched row" do
      expect(result.people_created).to eq(3)
    end

    it "skips the duplicate and the incomplete rows" do
      expect(result.skipped.size).to eq(2)
    end

    it "splits matched vs unmatched organizations" do
      expect(result.organizations_linked).to eq(2)
      expect(result.organizations_to_reconcile).to eq(1)
    end

    it "counts the rows carrying a payment and their total" do
      expect(result.payments_recorded).to eq(2)
      expect(result.payments_amount_cents).to eq(1599)
    end

    it "counts the discount that comps an underpaid row" do
      expect(result.discounts_recorded).to eq(1)
      expect(result.discounts_amount_cents).to eq(599)
    end

    it "writes nothing" do
      expect { import(dry_run: true) }.not_to change(Person, :count)
      expect { import(dry_run: true) }.not_to change(FormSubmission, :count)
      expect { import(dry_run: true) }.not_to change(Payment, :count)
      expect { import(dry_run: true) }.not_to change(Discount, :count)
      expect { import(dry_run: true) }.not_to change(Allocation, :count)
    end
  end

  describe "person matching parity" do
    it "matches on email + last name + first name, tolerating a legal-name swap" do
      create(:person, first_name: "Jordan", last_name: "Rivera", email: "jordan.rivera@example.org")
      result = import(dry_run: true)
      expect(result.people_matched).to eq(1)
      expect(result.people_created).to eq(2)
    end

    it "does not match when only the email and last name agree but the first name differs" do
      create(:person, first_name: "Different", last_name: "Rivera", email: "jordan.rivera@example.org")
      result = import(dry_run: true)
      expect(result.people_matched).to eq(0)
      expect(result.people_created).to eq(3)
    end
  end

  describe "the real import" do
    it "creates people and attended registrations" do
      expect { import(dry_run: false) }
        .to change(Person, :count).by(3)
        .and change { event.event_registrations.count }.by(3)

      expect(event.event_registrations.pluck(:status).uniq).to eq([ "attended" ])
    end

    it "simulates a registration form submission with the row's answers" do
      import(dry_run: false)
      person = Person.find_by(email: "casey.rivera@example.org")
      submission = person.form_submissions.find_by(event: event, role: "registration")

      expect(submission).to be_present
      answers = submission.form_answers.joins(:form_field).pluck("form_fields.field_identifier", :submitted_answer).to_h
      expect(answers).to include(
        "last_name" => "Rivera",
        "primary_email" => "casey.rivera@example.org",
        "organization_name" => "Unknown Org LLC"
      )
    end

    it "links a matched organization to the registration" do
      import(dry_run: false)
      registration = registration_for("jordan.rivera@example.org")
      expect(registration.organizations.pluck(:name)).to eq([ "Sample Org" ])
    end

    it "mints a facilitator affiliation for a matched org on a training event" do
      import(dry_run: false)
      person = Person.find_by(email: "jordan.rivera@example.org")
      affiliation = person.affiliations.find_by(title: Affiliation::FACILITATOR_TITLE)
      expect(affiliation.organization.name).to eq("Sample Org")
    end

    it "leaves an unmatched org for reconciliation — answer stored, nothing linked" do
      import(dry_run: false)
      registration = registration_for("casey.rivera@example.org")
      expect(registration.organizations).to be_empty
      expect(EventRegistration.organization_linking_status("pending", event)).to include(registration)
    end

    it "does not create the unmatched organization" do
      expect { import(dry_run: false) }.not_to change { Organization.where(name: "Unknown Org LLC").count }
    end

    it "does not duplicate a person already in the system" do
      create(:person, first_name: "Jordan", last_name: "Rivera", email: "jordan.rivera@example.org")
      expect { import(dry_run: false) }.to change(Person, :count).by(2)
    end

    it "attributes new people to the importing admin" do
      admin = create(:user)
      described_class.call(file_path: csv_path, event: event, import_user: admin, dry_run: false)
      expect(Person.find_by(email: "morgan.quinn@example.org").created_by).to eq(admin)
    end

    it "promotes an existing non-attended registration to attended" do
      person = create(:person, first_name: "Jordan", last_name: "Rivera", email: "jordan.rivera@example.org")
      registration = create(:event_registration, event: event, registrant: person, status: "registered")

      result = import(dry_run: false)

      expect(registration.reload.status).to eq("attended")
      expect(result.registrations_updated).to eq(1)
    end

    it "marks its own submission as imported" do
      import(dry_run: false)
      submission = Person.find_by(email: "morgan.quinn@example.org").form_submissions.find_by(event: event, role: "registration")
      expect(submission.metadata).to include("imported_from")
    end

    it "adds its own submission alongside a real registrant's, leaving theirs untouched" do
      person = create(:person, first_name: "Jordan", last_name: "Rivera", email: "jordan.rivera@example.org")
      create(:event_registration, event: event, registrant: person, status: "registered")
      real = FormSubmission.create!(person: person, form: event.registration_form, event: event, role: "registration")

      expect { import(dry_run: false) }
        .to change { person.form_submissions.where(event: event, role: "registration").count }.by(1)
      expect(real.reload.form_answers).to be_empty
      expect(real.reload.metadata).to be_blank
    end

    it "is idempotent — re-running does not pile up submissions" do
      import(dry_run: false)
      expect { import(dry_run: false) }.not_to change(FormSubmission, :count)
    end

    context "on a non-facilitator-training event" do
      let(:event) { create(:event, facilitator_training: false) }

      it "links the org but mints no facilitator affiliation" do
        import(dry_run: false)
        person = Person.find_by(email: "jordan.rivera@example.org")
        expect(registration_for("jordan.rivera@example.org").organizations.pluck(:name)).to eq([ "Sample Org" ])
        expect(person.affiliations.where(title: Affiliation::FACILITATOR_TITLE)).to be_empty
      end
    end
  end

  describe "payments" do
    it "records the payment actually paid and marks the registration paid in full" do
      import(dry_run: false)
      registration = registration_for("jordan.rivera@example.org")

      expect(registration).to be_paid_in_full
      expect(registration).to be_payment_received
      allocation = registration.allocations.find_by(source_type: "Payment")
      expect(allocation.amount).to eq(500)
      expect(allocation.source).to be_a(CashPayment)
    end

    it "comps the unpaid remainder with a discount so a partial payment reads as paid" do
      import(dry_run: false)
      registration = registration_for("jordan.rivera@example.org")
      discount_allocation = registration.allocations.find_by(source_type: "Discount")

      expect(discount_allocation.amount).to eq(599)
      expect(registration.allocations_sum).to eq(1099)
    end

    it "creates no discount when the payment covers the full cost" do
      import(dry_run: false)
      registration = registration_for("casey.rivera@example.org")

      expect(registration.allocations.where(source_type: "Discount")).to be_empty
      expect(registration.allocations.find_by(source_type: "Payment").amount).to eq(1099)
    end

    it "uses the check number for a check-type row" do
      import(dry_run: false)
      registration = registration_for("casey.rivera@example.org")
      payment = registration.allocations.find_by(source_type: "Payment").source

      expect(payment).to be_a(CheckPayment)
      expect(payment.check_number).to eq("12345")
    end

    it "records no payment or discount for a row without an amount" do
      import(dry_run: false)
      registration = registration_for("morgan.quinn@example.org")
      expect(registration.allocations).to be_empty
    end

    it "creates one payment per paying row and a discount only for the underpaid one" do
      expect { import(dry_run: false) }
        .to change(Payment, :count).by(2)
        .and change(Discount, :count).by(1)
    end

    it "stamps the payment as imported and scoped to the event" do
      import(dry_run: false)
      payment = registration_for("jordan.rivera@example.org").allocations.find_by(source_type: "Payment").source
      expect(payment.metadata).to include("imported_from", "event_id" => event.id)
    end

    it "reports the payments and discounts recorded" do
      result = import(dry_run: false)
      expect(result.payments_recorded).to eq(2)
      expect(result.payments_amount_cents).to eq(1599)
      expect(result.discounts_recorded).to eq(1)
      expect(result.discounts_amount_cents).to eq(599)
    end

    it "is idempotent — re-running adds no duplicate payments, discounts, or allocations" do
      import(dry_run: false)
      expect { import(dry_run: false) }.not_to change(Payment, :count)
      expect { import(dry_run: false) }.not_to change(Discount, :count)
      expect { import(dry_run: false) }.not_to change(Allocation, :count)
    end

    context "on a free event" do
      let(:event) { create(:event, cost_cents: 0, facilitator_training: true) }

      it "ignores the amount, recording no payment or discount" do
        expect { import(dry_run: false) }.not_to change(Payment, :count)
        expect { import(dry_run: false) }.not_to change(Discount, :count)
        expect(registration_for("jordan.rivera@example.org").allocations).to be_empty
      end
    end
  end

  describe "with the extended columns" do
    let(:event) { create(:event, facilitator_training: true, start_date: 3.days.ago, end_date: 1.day.ago) }

    def import_rows(*rows, dry_run: false)
      file = Tempfile.new([ "registrants", ".csv" ])
      file.write(CSV.generate { |csv| rows.each { |row| csv << row } })
      file.close
      described_class.call(file_path: file.path, event: event, dry_run: dry_run)
    ensure
      file&.unlink
    end

    def registration_of(person)
      event.event_registrations.find_by(registrant: person)
    end

    describe "status" do
      it "defaults a blank status to attended and marks every day complete" do
        import_rows(%w[FirstName LastName EMail Status], %w[Pat Example pat@example.org] + [ "" ])
        registration = registration_of(Person.find_by(email: "pat@example.org"))

        expect(registration.status).to eq("attended")
        expect(registration.completed_day_count).to eq(event.day_count)
      end

      it "takes the status column, matching labels loosely" do
        import_rows(%w[FirstName LastName EMail Status], [ "Pat", "Example", "pat@example.org", "No show" ])

        expect(registration_of(Person.find_by(email: "pat@example.org")).status).to eq("no_show")
      end

      it "skips a row whose status it can't read" do
        result = import_rows(%w[FirstName LastName EMail Status], %w[Pat Example pat@example.org Maybe])

        expect(result.skipped.map(&:skipped_reason)).to eq([ "unknown status “Maybe”" ])
      end

      it "derives the status from the day columns when no status is given" do
        import_rows([ "FirstName", "LastName", "EMail", "Day 1", "Day 2", "Day 3" ], %w[Pat Example pat@example.org Yes No Yes])
        registration = registration_of(Person.find_by(email: "pat@example.org"))

        expect(registration.status).to eq("incomplete_attendance")
        expect([ registration.completed_day_1, registration.completed_day_2, registration.completed_day_3 ]).to eq([ true, false, true ])
      end

      it "keeps a cancelled registration and comments what the sheet said" do
        person = create(:person, first_name: "Pat", last_name: "Example", email: "pat@example.org")
        cancelled = create(:event_registration, event: event, registrant: person, status: "cancelled")

        result = import_rows(%w[FirstName LastName EMail], %w[Pat Example pat@example.org])

        expect(event.event_registrations.where(registrant: person).pluck(:status)).to eq([ "cancelled" ])
        expect(result.registrations_kept).to eq(1)
        expect(cancelled.comments.sole.body).to eq("Imported sheet said “Attended”; kept this registration's “Cancelled”.")
      end

      it "never walks an attended registration back to the sheet's lesser status" do
        person = create(:person, first_name: "Pat", last_name: "Example", email: "pat@example.org")
        attended = create(:event_registration, event: event, registrant: person, status: "attended")

        import_rows(%w[FirstName LastName EMail Status], [ "Pat", "Example", "pat@example.org", "No show" ])

        expect(attended.reload.status).to eq("attended")
        expect(attended.comments.sole.body).to include("said “No show”", "kept this registration's “Attended”")
      end

      it "leaves the day columns off a registration that kept its own status" do
        person = create(:person, first_name: "Pat", last_name: "Example", email: "pat@example.org")
        no_show = create(:event_registration, event: event, registrant: person, status: "no_show")

        result = import_rows(%w[FirstName LastName EMail Status Day1 InvoiceRequested],
                             [ "Pat", "Example", "pat@example.org", "Attended", "Yes", "Yes" ])

        expect(no_show.reload).to have_attributes(status: "no_show", completed_day_1: false, invoice_requested: true)
        expect(result.rows.first.warnings).to include("Day columns not applied — the registration keeps its own status")
      end

      it "adds no second comment when the same sheet is imported again" do
        person = create(:person, first_name: "Pat", last_name: "Example", email: "pat@example.org")
        no_show = create(:event_registration, event: event, registrant: person, status: "no_show")

        2.times { import_rows(%w[FirstName LastName EMail], %w[Pat Example pat@example.org]) }

        expect(no_show.reload.status).to eq("no_show")
        expect(no_show.comments.count).to eq(1)
      end

      it "applies the sheet's status to a registration still only registered" do
        person = create(:person, first_name: "Pat", last_name: "Example", email: "pat@example.org")
        registration = create(:event_registration, event: event, registrant: person, status: "registered")

        result = import_rows(%w[FirstName LastName EMail Status], %w[Pat Example pat@example.org Attended])

        expect(registration.reload.status).to eq("attended")
        expect(registration.comments).to be_empty
        expect(result.registrations_updated).to eq(1)
      end

      it "records a cancellation on an active registration without emailing anyone" do
        person = create(:person, first_name: "Pat", last_name: "Example", email: "pat@example.org")
        registration = create(:event_registration, event: event, registrant: person, status: "registered")

        expect {
          import_rows(%w[FirstName LastName EMail Status], %w[Pat Example pat@example.org Cancelled])
        }.not_to change(Notification, :count)
        expect(registration.reload.status).to eq("cancelled")
      end

      it "sets the registration date from RegisteredOn" do
        import_rows(%w[FirstName LastName EMail RegisteredOn], %w[Pat Example pat@example.org 3/14/2024])

        expect(registration_of(Person.find_by(email: "pat@example.org")).created_at.to_date).to eq(Date.new(2024, 3, 14))
      end
    end

    describe "rows without an email" do
      let!(:organization) { create(:organization, name: "Sunrise Center") }

      it "matches the same-named person affiliated with the row's organization" do
        create(:person, first_name: "Sam", last_name: "Sample")
        affiliated = create(:person, first_name: "Sam", last_name: "Sample")
        create(:affiliation, person: affiliated, organization: organization, title: "Counselor")

        result = import_rows(%w[FirstName LastName Organization], [ "Sam", "Sample", "Sunrise Center" ])

        expect(registration_of(affiliated)).to be_present
        expect(result.rows.first.person_status).to eq(:matched_by_name_and_organization)
      end

      it "matches by name alone when only one person carries it" do
        person = create(:person, first_name: "Sam", last_name: "Sample")

        expect { import_rows(%w[FirstName LastName], %w[Sam Sample]) }.not_to change(Person, :count)
        expect(registration_of(person)).to be_present
      end

      it "creates a new person with the next placeholder free for that name" do
        create(:person, first_name: "Sam", last_name: "Sample", email: "1@example.com")
        create(:person, first_name: "Sam", last_name: "Sample", email: "sam.sample@example.org")

        expect { import_rows(%w[FirstName LastName], %w[Sam Sample]) }.to change(Person, :count).by(1)

        expect(Person.where(first_name: "Sam", last_name: "Sample").pluck(:email)).to include("2@example.com")
      end

      it "leaves the first placeholder free for a different name to use" do
        create(:person, first_name: "Other", last_name: "Person", email: "1@example.com")

        import_rows(%w[FirstName LastName], %w[Sam Sample])

        expect(Person.find_by(first_name: "Sam", last_name: "Sample").email).to eq("1@example.com")
      end

      it "creates a new person when the name is ambiguous" do
        create_list(:person, 2, first_name: "Sam", last_name: "Sample")

        expect { import_rows(%w[FirstName LastName], %w[Sam Sample]) }.to change(Person, :count).by(1)
      end

      it "skips a repeat of the same name and organization in the file" do
        result = import_rows(%w[FirstName LastName Organization], [ "Sam", "Sample", "Sunrise Center" ], [ "Sam", "Sample", "Sunrise Center" ])

        expect(result.skipped.size).to eq(1)
      end
    end

    describe "organizations" do
      let!(:organization) { create(:organization, name: "Sunrise Center", website_url: "https://sunrise.example.org") }

      it "matches a name that differs only by punctuation or a legal suffix" do
        result = import_rows(%w[FirstName LastName EMail Organization], [ "Pat", "Example", "pat@example.org", "Sunrise Center, Inc." ])

        expect(registration_of(Person.find_by(email: "pat@example.org")).organizations).to eq([ organization ])
        expect(result.rows.first.organization_status).to eq(:linked_by_spelling)
      end

      it "adds the work address and position but keeps the org's own website" do
        import_rows(
          %w[FirstName LastName EMail Organization Position OrganizationWebsite OrganizationStreet OrganizationCity OrganizationState OrganizationZip],
          [ "Pat", "Example", "pat@example.org", "Sunrise Center", "Counselor", "https://other.example.org", "1 Main St", "Springfield", "IL", "62701" ]
        )
        person = Person.find_by(email: "pat@example.org")

        expect(organization.reload.website_url).to eq("https://sunrise.example.org")
        expect(organization.addresses.pluck(:city)).to eq([ "Springfield" ])
        expect(person.affiliations.pluck(:title)).to include("Counselor")
      end
    end

    describe "the person's profile" do
      let!(:sector) { create(:sector, :published, name: "Education") }
      let!(:age_group) { create(:category, :published, name: "Teens", category_type: create(:category_type, name: "AgeRange")) }

      let(:header) { %w[FirstName LastName EMail Street City State Zip Phone PrimarySector PrimaryAgeGroup Pronouns] }
      let(:row) { [ "Pat", "Example", "pat@example.org", "2 Oak Ave", "Springfield", "IL", "62701", "555-0100", "education", "Teens", "they/them" ] }

      it "fills a new person's address, phone, tags, and pronouns" do
        import_rows(header, row)
        person = Person.find_by(email: "pat@example.org")

        expect(person.addresses.find_by(primary: true).city).to eq("Springfield")
        expect(person.contact_methods.find_by(kind: :phone).value).to eq("555-0100")
        expect(person.primary_sector).to eq(sector)
        expect(person.primary_age_groups.map(&:id)).to eq([ age_group.id ])
        expect(person.pronouns).to eq("they/them")
      end

      it "keeps a matched person's current primary address and adds the sheet's beside it" do
        person = create(:person, first_name: "Pat", last_name: "Example", email: "pat@example.org", pronouns: "she/her")
        current = person.addresses.create!(street_address: "9 Elm St", city: "Portland", state: "OR", zip_code: "97201",
                                           locality: "Unknown", address_type: "personal", primary: true)

        import_rows(header, row)

        expect(current.reload).to be_primary
        expect(person.addresses.find_by(city: "Springfield")).not_to be_primary
        expect(person.reload.pronouns).to eq("she/her")
      end

      it "reports and comments a person value it kept rather than overwrote" do
        person = create(:person, first_name: "Pat", last_name: "Example", email: "pat@example.org", pronouns: "she/her")

        result = import_rows(%w[FirstName LastName EMail Pronouns], [ "Pat", "Example", "pat@example.org", "they/them" ])

        expect(person.reload.pronouns).to eq("she/her")
        expect(result.rows.first.warnings).to include("Kept pronouns “she/her” — sheet said “they/them”")
        expect(person.comments.sole.body).to eq(
          "Imported sheet disagreed and was not applied: Pronouns “they/them” (kept “she/her”)."
        )
      end

      it "stays quiet when the sheet agrees with what's on file" do
        person = create(:person, first_name: "Pat", last_name: "Example", email: "pat@example.org", pronouns: "they/them")

        result = import_rows(%w[FirstName LastName EMail Pronouns], [ "Pat", "Example", "pat@example.org", "they/them" ])

        expect(result.rows.first.warnings).to be_empty
        expect(person.comments).to be_empty
      end

      it "reports an organization value it kept rather than overwrote" do
        organization = create(:organization, name: "Sunrise Center", website_url: "https://sunrise.example.org")

        result = import_rows(%w[FirstName LastName EMail Organization OrganizationWebsite],
                             [ "Pat", "Example", "pat@example.org", "Sunrise Center", "https://other.example.org" ])

        expect(organization.reload.website_url).to eq("https://sunrise.example.org")
        expect(result.rows.first.warnings.join).to include("sheet said “https://other.example.org”")
        expect(organization.comments.sole.body).to include("Website “https://other.example.org”")
      end

      it "warns about a sector it doesn't recognize" do
        result = import_rows(%w[FirstName LastName EMail AdditionalSectors], [ "Pat", "Example", "pat@example.org", "Education, Astronomy" ])

        expect(result.rows.first.warnings).to eq([ "Unknown sector “Astronomy”" ])
      end
    end

    describe "CE, scholarships, and follow-up flags" do
      let(:event) do
        create(:event, facilitator_training: true, start_date: 3.days.ago, end_date: 1.day.ago,
                       ce_hours_offered: 6, ce_hours_cost_cents: 2000)
      end

      it "enrolls the registrant in CE against their license" do
        import_rows(%w[FirstName LastName EMail CE LicenseType LicenseNumber], %w[Pat Example pat@example.org Yes LCSW 12345])
        ce = registration_of(Person.find_by(email: "pat@example.org")).continuing_education_registrations.sole

        expect(ce.professional_license).to have_attributes(kind: "LCSW", number: "12345")
      end

      it "applies the scholarship, then the payment across registration and CE, then comps the rest" do
        import_rows(%w[FirstName LastName EMail CE Scholarship AmountPaid], %w[Pat Example pat@example.org Yes 3.00 10])
        registration = registration_of(Person.find_by(email: "pat@example.org"))
        ce = registration.continuing_education_registrations.sole

        expect(registration.scholarships.sole.amount_cents).to eq(300)
        expect(registration.allocations.find_by(source_type: "Payment").amount).to eq(799)
        expect(ce.allocations.find_by(source_type: "Payment").amount).to eq(201)
        expect(ce.allocations.find_by(source_type: "Discount").amount).to eq(1799)
        expect(registration).to be_paid_in_full
      end

      it "leaves a CE the row never mentions out of the payment and the comping discount" do
        person = create(:person, first_name: "Pat", last_name: "Example", email: "pat@example.org")
        registration = create(:event_registration, event: event, registrant: person, status: "registered")
        ce = ContinuingEducationRegistration.enroll!(event_registration: registration, number: "12345", kind: "LCSW")

        import_rows(%w[FirstName LastName EMail AmountPaid], [ "Pat", "Example", "pat@example.org", "7.50" ])

        expect(registration.reload).to be_paid_in_full
        expect(ce.reload.allocations).to be_empty
        expect(ce).not_to be_paid_in_full
      end

      it "reports nothing to pay when the scholarship already covers the cost" do
        result = import_rows(%w[FirstName LastName EMail Scholarship AmountPaid],
                             [ "Pat", "Example", "pat@example.org", "10.99", "10.99" ], dry_run: true)

        expect(result.rows.first.payment_status).to eq(:nothing_owed)
        expect(result.payments_recorded).to eq(0)
      end

      it "warns that CE stays unpaid when the row carries no payment" do
        result = import_rows(%w[FirstName LastName EMail CE], %w[Pat Example pat@example.org Yes], dry_run: true)

        expect(result.rows.first.warnings).to eq([ "CE stays unpaid ($20) — no CE certificate until it's paid" ])
      end

      it "sets the yes/no flags and completion dates" do
        import_rows(%w[FirstName LastName EMail InvoiceRequested PostSurveyCompleted], %w[Pat Example pat@example.org Yes Yes])
        registration = registration_of(Person.find_by(email: "pat@example.org"))

        expect(registration.invoice_requested).to be(true)
        expect(registration.post_survey_completed_at.to_date).to eq(event.end_date.to_date)
      end
    end

    describe "one payment covering several people" do
      let(:event) { create(:event, facilitator_training: true, cost_cents: 50_000) }
      let(:header) { %w[FirstName LastName EMail AmountPaid PaymentType CheckNumber] }

      def registrations_for(*emails)
        emails.map { |email| registration_of(Person.find_by(email: email)) }
      end

      it "splits one check repeated on every row across those registrations" do
        import_rows(header,
                    [ "Pat", "Example", "pat@example.org", "1000.00", "Check", "12345" ],
                    [ "Sam", "Sample", "sam@example.org", "1000.00", "Check", "12345" ])

        payments = Payment.where(amount_cents: 100_000)
        expect(payments.count).to eq(1)
        expect(registrations_for("pat@example.org", "sam@example.org")).to all(be_paid_in_full)
        expect(payments.sole.allocations.pluck(:amount)).to eq([ 50_000, 50_000 ])
        expect(Discount.count).to eq(0)
      end

      it "sums the rows when each carries that person's share" do
        import_rows(%w[FirstName LastName EMail AmountPaid PaymentType BulkPayment],
                    [ "Pat", "Example", "pat@example.org", "500.00", "Cash", "Team A" ],
                    [ "Sam", "Sample", "sam@example.org", "500.00", "Cash", "Team A" ])

        payment = Payment.sole
        expect(payment.amount_cents).to eq(100_000)
        expect(payment.allocations.pluck(:amount)).to eq([ 50_000, 50_000 ])
      end

      it "records the shared organization as the payer" do
        organization = create(:organization, name: "Sunrise Center")
        import_rows(%w[FirstName LastName EMail Organization AmountPaid PaymentType BulkPayment],
                    [ "Pat", "Example", "pat@example.org", "Sunrise Center", "1000.00", "Cash", "Team A" ],
                    [ "Sam", "Sample", "sam@example.org", "Sunrise Center", "1000.00", "Cash", "Team A" ])

        expect(Payment.sole).to have_attributes(organization: organization, person: nil)
      end

      it "adds no second payment when the same sheet is imported again" do
        rows = [ header,
                 [ "Pat", "Example", "pat@example.org", "1000.00", "Check", "12345" ],
                 [ "Sam", "Sample", "sam@example.org", "1000.00", "Check", "12345" ] ]

        2.times { import_rows(*rows) }

        expect(Payment.count).to eq(1)
        expect(Allocation.where(source_type: "Payment").count).to eq(2)
      end

      it "previews each person's share of the group rather than the whole payment" do
        result = import_rows(header,
                             [ "Pat", "Example", "pat@example.org", "1000.00", "Check", "12345" ],
                             [ "Sam", "Sample", "sam@example.org", "1000.00", "Check", "12345" ],
                             dry_run: true)

        expect(result.payments_recorded).to eq(1)
        expect(result.payments_amount_cents).to eq(100_000)
        expect(result.rows.map(&:payment_amount_cents)).to eq([ 50_000, 50_000 ])
        expect(result.rows.map(&:bulk_size)).to eq([ 2, 2 ])
        expect(result.rows.map(&:payment_total_cents)).to eq([ 100_000, 100_000 ])
      end

      it "shows up on the event's bulk payments page, reusing an existing bulk payment form" do
        form = create(:form, name: "Bulk payment", role: "bulk_payment")

        expect {
          import_rows(header,
                      [ "Pat", "Example", "pat@example.org", "1000.00", "Check", "12345" ],
                      [ "Sam", "Sample", "sam@example.org", "1000.00", "Check", "12345" ])
        }.not_to change(Form, :count)

        submission = event.form_submissions.find_by(role: "bulk_payment")
        expect(event.reload.bulk_payment_form).to eq(form)
        expect(submission.payment).to eq(Payment.sole)
        expect(submission.linked_registration_ids).to match_array(registrations_for("pat@example.org", "sam@example.org").map(&:id))
      end

      it "creates a bulk payment form only when the install has none" do
        expect {
          import_rows(header,
                      [ "Pat", "Example", "pat@example.org", "1000.00", "Check", "12345" ],
                      [ "Sam", "Sample", "sam@example.org", "1000.00", "Check", "12345" ])
        }.to change(Form, :count).by(1)

        expect(event.reload.bulk_payment_form.role).to eq("bulk_payment")
      end

      it "records the attendees so the card can match them to registrants" do
        form = create(:form, role: "bulk_payment")
        create(:form_field, form: form, field_identifier: "bulk_payment_attendees")

        import_rows(header,
                    [ "Pat", "Example", "pat@example.org", "1000.00", "Check", "12345" ],
                    [ "Sam", "Sample", "sam@example.org", "1000.00", "Check", "12345" ])

        attendees = event.form_submissions.find_by(role: "bulk_payment").bulk_payment_attendees
        expect(attendees.map { |a| a["last_name"] }).to eq(%w[Example Sample])
      end

      it "leaves a single-row payment off the bulk payments page" do
        create(:form, role: "bulk_payment")

        import_rows(header, [ "Pat", "Example", "pat@example.org", "500.00", "Check", "999" ])

        expect(event.form_submissions.where(role: "bulk_payment")).to be_empty
      end

      it "keeps an unrelated cash row on its own payment" do
        import_rows(%w[FirstName LastName EMail AmountPaid PaymentType],
                    [ "Pat", "Example", "pat@example.org", "500.00", "Cash" ],
                    [ "Sam", "Sample", "sam@example.org", "500.00", "Cash" ])

        expect(Payment.pluck(:amount_cents)).to eq([ 50_000, 50_000 ])
      end
    end

    it "lists the headers it doesn't recognize" do
      result = import_rows(%w[FirstName LastName EMail FavoriteColor], %w[Pat Example pat@example.org Blue], dry_run: true)

      expect(result.unrecognized_headers).to eq([ "FavoriteColor" ])
    end
  end

  def registration_for(email)
    event.event_registrations.find_by(registrant: Person.find_by(email: email))
  end
end
