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
    it "is true for primary_email and organization_name, false for affiliation" do
      expect(build(:profile_change_request, :primary_email)).to be_auto_appliable
      expect(build(:profile_change_request, :organization_name)).to be_auto_appliable
      expect(build(:profile_change_request, field: "affiliation")).not_to be_auto_appliable
    end
  end

  describe "#current_value" do
    it "reads the person's user email for primary_email" do
      user = create(:user, :with_person, email: "current@example.com")
      request = build(:profile_change_request, :primary_email, person: user.person)
      expect(request.current_value).to eq("current@example.com")
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
