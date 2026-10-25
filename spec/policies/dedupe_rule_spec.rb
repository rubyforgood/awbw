require "rails_helper"

RSpec.describe "#dedupe? on each deduped model's policy", type: :policy do
  [ Address, Category, EventRegistration, Organization, Person, Sector, User, Workshop ].each do |model|
    describe ActionPolicy.lookup(model) do
      it "allows an admin" do
        expect(described_class.new(model, user: build_stubbed(:user, :admin))).to be_allowed_to(:dedupe?)
      end

      it "denies a non-admin" do
        expect(described_class.new(model, user: build_stubbed(:user))).not_to be_allowed_to(:dedupe?)
      end

      it "denies a guest" do
        expect(described_class.new(model, user: nil)).not_to be_allowed_to(:dedupe?)
      end
    end
  end
end
