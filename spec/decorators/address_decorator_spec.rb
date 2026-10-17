require "rails_helper"

RSpec.describe AddressDecorator do
  describe "#address_type_label" do
    it "humanizes the address type" do
      expect(build(:address, address_type: "personal").decorate.address_type_label).to eq("Personal")
    end

    it "is nil without an address type" do
      expect(build(:address, address_type: nil).decorate.address_type_label).to be_nil
    end
  end
end
