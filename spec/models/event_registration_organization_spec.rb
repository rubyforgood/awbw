require "rails_helper"

RSpec.describe EventRegistrationOrganization, type: :model do
  describe "associations" do
    it { should belong_to(:event_registration).required }
    it { should belong_to(:organization).required }
    it { should belong_to(:form_submission).optional }
  end

  describe "validations" do
    subject { create(:event_registration_organization) }

    it { should validate_uniqueness_of(:organization_id).scoped_to(:event_registration_id) }
  end

  describe "autofill provenance" do
    subject(:link) { create(:event_registration_organization) }

    def change(field, label, value, scope: nil)
      OrganizationServices::AutofillChange.new(field: field, label: label, value: value, scope: scope)
    end

    it "has no changes until the form autofills something" do
      expect(link.form_autofill_changes).to eq([])
    end

    it "records each field alongside the value that landed in it" do
      link.record_autofill([ change("website_url", "Website", "https://helpinghands.org") ])

      recorded = link.reload.form_autofill_changes
      expect(recorded.map(&:field)).to eq([ "website_url" ])
      expect(recorded.map(&:value)).to eq([ "https://helpinghands.org" ])
      expect(recorded.map(&:description)).to eq([ "Website" ])
    end

    # An org keeps one work address per city, so the field alone wouldn't say
    # which address a ZIP belongs to.
    it "names the address a field belongs to" do
      link.record_autofill([ change("zip_code", "ZIP", "78701", scope: "Austin work address") ])

      expect(link.reload.form_autofill_changes.first.description).to eq("ZIP on the Austin work address")
    end

    # A registration accrues autofills across submissions and relinks, so each call
    # adds to the record rather than replacing it.
    it "keeps what is already recorded when a later submission adds another field" do
      link.record_autofill([ change("website_url", "Website", "https://a.org") ])

      link.record_autofill([ change("agency_type", "Type", "For-profit") ])

      expect(link.reload.form_autofill_changes.map(&:field)).to eq(%w[website_url agency_type])
    end

    # The note answers "what did this registration put on the org", so a corrected
    # resubmission should leave the value the org ended up with, not both values.
    it "replaces the recorded value when a later submission rewrites the same field" do
      link.record_autofill([ change("website_url", "Website", "https://old.org") ])

      link.record_autofill([ change("website_url", "Website", "https://new.org") ])

      expect(link.reload.form_autofill_changes.map(&:value)).to eq([ "https://new.org" ])
    end

    # Same field on two different work addresses are two separate facts.
    it "keeps the same field recorded separately per address" do
      link.record_autofill([ change("zip_code", "ZIP", "78701", scope: "Austin work address") ])

      link.record_autofill([ change("zip_code", "ZIP", "89501", scope: "Reno work address") ])

      expect(link.reload.form_autofill_changes.map(&:value)).to contain_exactly("78701", "89501")
    end

    # A registrant resubmitting what's already on file changed nothing, so the
    # link isn't rewritten and its updated_at doesn't move.
    it "issues no write when the same change is already recorded" do
      link.record_autofill([ change("website_url", "Website", "https://a.org") ])

      expect(updates_while { link.record_autofill([ change("website_url", "Website", "https://a.org") ]) }).to be_empty
    end

    # Leaves the column NULL rather than writing an empty array.
    it "issues no write when nothing was autofilled" do
      link.reload

      expect(updates_while { link.record_autofill([]) }).to be_empty
      expect(link.reload.read_attribute(:form_autofill_changes)).to be_nil
      expect(link.form_autofill_changes).to eq([])
    end

    # The column is a display aid, not a ledger — a row written before a key
    # existed should degrade, not break the linking page.
    it "skips a stored entry with no field rather than raising" do
      link.update!(form_autofill_changes: [ { "label" => "Website" }, { "field" => "agency_type", "label" => "Type", "value" => "For-profit" } ])

      expect(link.reload.form_autofill_changes.map(&:field)).to eq([ "agency_type" ])
    end

    # Matches only a statement that starts with UPDATE — "updated_at" appears in
    # the column list of every INSERT.
    def updates_while
      statements = []
      subscriber = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
      statements.grep(/\AUPDATE\b/i)
    end
  end

  describe "pinned submission" do
    subject(:link) { create(:event_registration_organization) }

    let(:submission) { create(:form_submission) }

    it "has none until a submission is pinned" do
      expect(link.form_submission).to be_nil
    end

    it "pins the submission whose answers describe the org" do
      link.record_form_submission(submission)

      expect(link.reload.form_submission).to eq(submission)
    end

    # A registrant applying again describes the org afresh, and the profile sync
    # is latest-wins, so the pin follows the newest submission.
    it "repins to a later submission" do
      link.record_form_submission(submission)

      later = create(:form_submission)
      link.record_form_submission(later)

      expect(link.reload.form_submission).to eq(later)
    end

    it "issues no write when the same submission is already pinned" do
      link.record_form_submission(submission)

      expect(updates_while { link.record_form_submission(submission) }).to be_empty
    end

    # An org an admin linked by hand matches no submission, so there's nothing to pin.
    it "issues no write when there is no submission" do
      link.reload

      expect(updates_while { link.record_form_submission(nil) }).to be_empty
      expect(link.reload.form_submission_id).to be_nil
    end

    def updates_while
      statements = []
      subscriber = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
      statements.grep(/\AUPDATE\b/i)
    end
  end
end
