require "rails_helper"

RSpec.describe EventRegistrationImporter do
  let(:event) { create(:event) }
  let(:csv_path) { Rails.root.join("spec/fixtures/files/event_registrants_import.csv").to_s }

  before { create(:organization, name: "A New Leaf") }

  def import(dry_run:)
    described_class.call(file_path: csv_path, event: event, extension: "csv", dry_run: dry_run)
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

    it "flags the row missing a last name as skipped" do
      missing = result.rows.find { |r| r.skipped_reason&.include?("last name") }
      expect(missing).to be_present
    end

    it "flags a repeated person as a duplicate of the earlier row" do
      duplicate = result.rows.find { |r| r.skipped_reason&.include?("duplicate") }
      expect(duplicate).to be_present
      expect(duplicate.skipped_reason).to match(/row 1/)
    end

    it "matches an organization that exists and reports the unknown one" do
      expect(result.organizations_linked).to eq(2)
      expect(result.organizations_unmatched).to eq(1)
    end

    it "writes nothing" do
      expect { import(dry_run: true) }.not_to change(Person, :count)
      expect { import(dry_run: true) }.not_to change(EventRegistration, :count)
    end
  end

  describe "matching an existing person" do
    subject(:result) { import(dry_run: true) }

    let!(:existing) do
      create(:person, first_name: "Cid", last_name: "Acosta", email: "cacosta@turnanewleaf.org")
    end

    it "reuses the person instead of counting a new one" do
      expect(result.people_matched).to eq(1)
      expect(result.people_created).to eq(2)
    end
  end

  describe "the real import" do
    it "creates people and attended registrations" do
      expect { import(dry_run: false) }
        .to change(Person, :count).by(3)
        .and change { event.event_registrations.count }.by(3)

      expect(event.event_registrations.pluck(:status).uniq).to eq([ "attended" ])
    end

    it "links matched organizations to the registration" do
      import(dry_run: false)
      person = Person.find_by(email: "cacosta@turnanewleaf.org")
      registration = event.event_registrations.find_by(registrant: person)
      expect(registration.organizations.pluck(:name)).to eq([ "A New Leaf" ])
    end

    it "does not create the unmatched organization" do
      expect { import(dry_run: false) }.not_to change { Organization.where(name: "Unknown Org LLC").count }
    end

    it "does not duplicate a person already in the system" do
      create(:person, first_name: "Cidney", last_name: "Acosta", email: "cacosta@turnanewleaf.org")
      expect { import(dry_run: false) }.to change(Person, :count).by(2)
    end

    it "promotes an existing non-attended registration to attended" do
      person = create(:person, last_name: "Acosta", email: "cacosta@turnanewleaf.org")
      registration = create(:event_registration, event: event, registrant: person, status: "registered")

      result = import(dry_run: false)

      expect(registration.reload.status).to eq("attended")
      expect(result.registrations_promoted).to eq(1)
    end

    it "leaves an already-attended registration untouched and counts it" do
      person = create(:person, last_name: "Acosta", email: "cacosta@turnanewleaf.org")
      create(:event_registration, event: event, registrant: person, status: "attended")

      result = import(dry_run: false)

      expect(result.registrations_already_attended).to eq(1)
      expect(result.registrations_created).to eq(2)
    end
  end
end
