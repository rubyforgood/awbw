require "rails_helper"

RSpec.describe EventRegistrationImporter do
  let(:event) { create(:event, facilitator_training: true) }
  let(:csv_path) { Rails.root.join("spec/fixtures/files/event_registrants_import.csv").to_s }

  before do
    create(:organization, name: "A New Leaf")
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

    it "writes nothing" do
      expect { import(dry_run: true) }.not_to change(Person, :count)
      expect { import(dry_run: true) }.not_to change(FormSubmission, :count)
    end
  end

  describe "person matching parity" do
    it "matches on email + last name + first name, tolerating a legal-name swap" do
      create(:person, first_name: "Cidney", last_name: "Acosta", email: "cacosta@turnanewleaf.org")
      result = import(dry_run: true)
      expect(result.people_matched).to eq(1)
      expect(result.people_created).to eq(2)
    end

    it "does not match when only the email and last name agree but the first name differs" do
      create(:person, first_name: "Different", last_name: "Acosta", email: "cacosta@turnanewleaf.org")
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
      person = Person.find_by(email: "macosta@wrcnbc.org")
      submission = person.form_submissions.find_by(event: event, role: "registration")

      expect(submission).to be_present
      answers = submission.form_answers.joins(:form_field).pluck("form_fields.field_identifier", :submitted_answer).to_h
      expect(answers).to include(
        "last_name" => "Acosta",
        "primary_email" => "macosta@wrcnbc.org",
        "organization_name" => "Unknown Org LLC"
      )
    end

    it "links a matched organization to the registration" do
      import(dry_run: false)
      registration = registration_for("cacosta@turnanewleaf.org")
      expect(registration.organizations.pluck(:name)).to eq([ "A New Leaf" ])
    end

    it "mints a facilitator affiliation for a matched org on a training event" do
      import(dry_run: false)
      person = Person.find_by(email: "cacosta@turnanewleaf.org")
      affiliation = person.affiliations.find_by(title: Affiliation::FACILITATOR_TITLE)
      expect(affiliation.organization.name).to eq("A New Leaf")
    end

    it "leaves an unmatched org for reconciliation — answer stored, nothing linked" do
      import(dry_run: false)
      registration = registration_for("macosta@wrcnbc.org")
      expect(registration.organizations).to be_empty
      expect(EventRegistration.organization_linking_status("pending", event)).to include(registration)
    end

    it "does not create the unmatched organization" do
      expect { import(dry_run: false) }.not_to change { Organization.where(name: "Unknown Org LLC").count }
    end

    it "does not duplicate a person already in the system" do
      create(:person, first_name: "Cidney", last_name: "Acosta", email: "cacosta@turnanewleaf.org")
      expect { import(dry_run: false) }.to change(Person, :count).by(2)
    end

    it "attributes new people to the importing admin" do
      admin = create(:user)
      described_class.call(file_path: csv_path, event: event, import_user: admin, dry_run: false)
      expect(Person.find_by(email: "kadams@rcoe.us").created_by).to eq(admin)
    end

    it "promotes an existing non-attended registration to attended" do
      person = create(:person, first_name: "Cidney", last_name: "Acosta", email: "cacosta@turnanewleaf.org")
      registration = create(:event_registration, event: event, registrant: person, status: "registered")

      result = import(dry_run: false)

      expect(registration.reload.status).to eq("attended")
      expect(result.registrations_promoted).to eq(1)
    end

    it "marks its own submission as imported" do
      import(dry_run: false)
      submission = Person.find_by(email: "kadams@rcoe.us").form_submissions.find_by(event: event, role: "registration")
      expect(submission.metadata).to include("imported_from")
    end

    it "adds its own submission alongside a real registrant's, leaving theirs untouched" do
      person = create(:person, first_name: "Cidney", last_name: "Acosta", email: "cacosta@turnanewleaf.org")
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
        person = Person.find_by(email: "cacosta@turnanewleaf.org")
        expect(registration_for("cacosta@turnanewleaf.org").organizations.pluck(:name)).to eq([ "A New Leaf" ])
        expect(person.affiliations.where(title: Affiliation::FACILITATOR_TITLE)).to be_empty
      end
    end
  end

  def registration_for(email)
    event.event_registrations.find_by(registrant: Person.find_by(email: email))
  end
end
