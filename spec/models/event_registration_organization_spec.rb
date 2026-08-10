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

  describe "form fill provenance" do
    subject(:link) { create(:event_registration_organization) }

    it "has no labels until a form fills something" do
      expect(link.form_filled_labels).to eq([])
    end

    it "records the labels a submission filled" do
      link.record_form_fills([ "website", "work address in Austin" ])

      expect(link.reload.form_filled_labels).to eq([ "website", "work address in Austin" ])
    end

    # A registration accrues fills across submissions and relinks, so each call
    # adds to the record rather than replacing it.
    it "keeps the fills already recorded when a later submission adds another" do
      link.record_form_fills([ "website" ])

      link.record_form_fills([ "type" ])

      expect(link.reload.form_filled_labels).to eq([ "website", "type" ])
    end

    it "does not record a label an earlier submission already filled twice" do
      link.record_form_fills([ "website" ])

      link.record_form_fills([ "website", "type" ])

      expect(link.reload.form_filled_labels).to eq([ "website", "type" ])
    end

    # A registrant resubmitting what's already on file changed nothing, so the
    # link isn't rewritten and its updated_at doesn't move.
    it "issues no write when the labels are already recorded" do
      link.record_form_fills([ "website" ])

      expect(updates_while { link.record_form_fills([ "website" ]) }).to be_empty
    end

    # Leaves the column NULL rather than writing an empty array.
    it "issues no write when nothing was filled" do
      link.reload

      expect(updates_while { link.record_form_fills([]) }).to be_empty
      expect(link.reload.form_filled_fields).to be_nil
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
