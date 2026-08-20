require "rails_helper"

RSpec.describe ProfessionalLicensePolicy, type: :policy do
  let(:owner) { create(:user, :with_person) }
  let(:admin) { create(:user, :admin) }
  let(:other) { create(:user, :with_person) }

  let(:license) { create(:professional_license, person: owner.person, number: "POL-1") }

  def policy_for(user:, record: license)
    described_class.new(record, user: user)
  end

  def attach_ce
    registration = create(:event_registration, registrant: owner.person)
    create(:continuing_education_registration, event_registration: registration, professional_license: license)
  end

  describe "#edit? / #update?" do
    context "an admin" do
      it "may always edit, even with CE registrations" do
        expect(policy_for(user: admin)).to be_allowed_to(:edit?)
        attach_ce
        expect(policy_for(user: admin, record: license.reload)).to be_allowed_to(:edit?)
      end
    end

    context "the holder (owner)" do
      it "may edit a license with no CE registrations" do
        expect(policy_for(user: owner)).to be_allowed_to(:edit?)
        expect(policy_for(user: owner)).to be_allowed_to(:update?)
      end

      it "may not edit once the license has CE registrations" do
        attach_ce
        expect(policy_for(user: owner, record: license.reload)).not_to be_allowed_to(:edit?)
      end
    end

    context "an unrelated user" do
      it "may not edit" do
        expect(policy_for(user: other)).not_to be_allowed_to(:edit?)
      end
    end
  end

  describe "#destroy?" do
    it "is allowed for the owner only when the license has no CE registrations" do
      expect(policy_for(user: owner)).to be_allowed_to(:destroy?)
      attach_ce
      expect(policy_for(user: owner, record: license.reload)).not_to be_allowed_to(:destroy?)
    end

    it "is blocked even for an admin once a CE registration exists" do
      attach_ce
      expect(policy_for(user: admin, record: license.reload)).not_to be_allowed_to(:destroy?)
    end
  end
end
