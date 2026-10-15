require "rails_helper"

RSpec.describe ProfileChangeRequest, type: :model do
  describe "validations" do
    it "requires a requested_value for auto-appliable fields" do
      request = build(:profile_change_request, :primary_email, requested_value: nil)
      expect(request).not_to be_valid
      expect(request.errors[:requested_value]).to be_present
    end

    it "requires a valid email for a primary_email request" do
      request = build(:profile_change_request, :primary_email, requested_value: "not-an-email")
      expect(request).not_to be_valid
    end

    it "requires a valid email for a secondary_email request" do
      request = build(:profile_change_request, :secondary_email, requested_value: "not-an-email")
      expect(request).not_to be_valid
    end

    it "accepts an other request with only details" do
      expect(build(:profile_change_request, :other)).to be_valid
    end

    it "requires details for an other request" do
      request = build(:profile_change_request, :other, details: nil)
      expect(request).not_to be_valid
      expect(request.errors[:details]).to be_present
    end

    it "requires details for a work address request" do
      affiliation = create(:affiliation)
      request = build(:profile_change_request, person: affiliation.person, affiliation: affiliation,
                                               requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_WORK_ADDRESS, details: nil)
      expect(request).not_to be_valid
      expect(request.errors[:details]).to be_present
    end

    describe "adding an organization that isn't in the portal" do
      let(:add) { { field: "affiliation", requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_ADD, proposed_title: "Counselor", details: nil } }

      it "accepts a typed organization name instead of a picked one" do
        request = build(:profile_change_request, **add, proposed_organization_name: "Hillside Shelter")
        expect(request).to be_valid
        expect(request).to be_new_organization
        expect(request).not_to be_auto_appliable
        expect(request.proposed_change_summary).to include("Hillside Shelter (not in the portal yet)")
      end

      it "needs either a picked organization or a typed name" do
        request = build(:profile_change_request, **add)
        expect(request).not_to be_valid
        expect(request.errors[:base].join).to include("type its name")
      end

      it "drops the typed name when an organization is picked" do
        request = build(:profile_change_request, **add, organization: create(:organization), proposed_organization_name: "Typo")
        request.validate
        expect(request.proposed_organization_name).to be_nil
        expect(request).to be_auto_appliable
      end
    end

    it "requires details for a free-form affiliation request" do
      request = build(:profile_change_request, field: "affiliation", details: nil)
      expect(request).not_to be_valid
      expect(request.errors[:details]).to be_present
    end

    it "rejects an unknown field" do
      request = build(:profile_change_request, field: "shoe_size")
      expect(request).not_to be_valid
    end

    it "rejects an affiliation that belongs to a different person" do
      other_affiliation = create(:affiliation)
      request = build(:profile_change_request, field: "affiliation", affiliation: other_affiliation)
      expect(request).not_to be_valid
      expect(request.errors[:affiliation]).to be_present
    end
  end

  describe "#auto_appliable?" do
    it "is true for the email fields and organization_name, false for affiliation" do
      expect(build(:profile_change_request, :primary_email)).to be_auto_appliable
      expect(build(:profile_change_request, :organization_name)).to be_auto_appliable
      expect(build(:profile_change_request, :secondary_email)).to be_auto_appliable
      expect(build(:profile_change_request, field: "affiliation")).not_to be_auto_appliable
      expect(build(:profile_change_request, :other)).not_to be_auto_appliable
    end
  end

  describe "#current_value" do
    it "reads the person's user email for primary_email" do
      user = create(:user, :with_person, email: "current@example.com")
      request = build(:profile_change_request, :primary_email, person: user.person)
      expect(request.current_value).to eq("current@example.com")
    end

    it "reads the person's email_2 for secondary_email" do
      person = create(:person, email_2: "second-current@example.com")
      request = build(:profile_change_request, :secondary_email, person: person)
      expect(request.current_value).to eq("second-current@example.com")
    end
  end

  describe "#resolve! and #decline!" do
    let(:reviewer) { create(:user, :admin) }
    let(:request) { create(:profile_change_request) }

    it "resolves with a method and reviewer" do
      request.resolve!(method: "manual", reviewer: reviewer)
      expect(request).to be_resolved
      expect(request.resolution_method).to eq("manual")
      expect(request.reviewed_by).to eq(reviewer)
      expect(request.reviewed_at).to be_present
    end

    it "declines with a reviewer" do
      request.decline!(reviewer: reviewer)
      expect(request).to be_declined
      expect(request.reviewed_by).to eq(reviewer)
    end
  end
end
