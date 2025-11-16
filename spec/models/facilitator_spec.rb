require "rails_helper"

RSpec.describe Facilitator, type: :model do
  describe "associations" do
    it { should have_one(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
  end

  describe "#name" do
    let(:user) { build(:user, first_name: "Jane", last_name: "Doe") }
    let(:facilitator) { build(:facilitator, user: user) }

    context "when display_name_preference is full_name" do
      it "returns the full name" do
        facilitator.display_name_preference = "full_name"
        expect(facilitator.name).to eq("Jane Doe")
      end
    end

    context "when display_name_preference is first_name_last_initial" do
      it "returns first name and last initial" do
        facilitator.display_name_preference = "first_name_last_initial"
        expect(facilitator.name).to eq("Jane D")
      end
    end

    context "when display_name_preference is first_name_only" do
      it "returns only the first name" do
        facilitator.display_name_preference = "first_name_only"
        expect(facilitator.name).to eq("Jane")
      end
    end

    context "when display_name_preference is last_name_only" do
      it "returns only the last name" do
        facilitator.display_name_preference = "last_name_only"
        expect(facilitator.name).to eq("Doe")
      end
    end

    context "when display_name_preference is nil or unknown" do
      it "defaults to full name" do
        facilitator.display_name_preference = nil
        expect(facilitator.name).to eq("Jane Doe")
      end
    end
  end
end
