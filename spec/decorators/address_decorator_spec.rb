require "rails_helper"

RSpec.describe AddressDecorator do
  let(:organization) { create(:organization) }

  it "labels a plain address with just its name" do
    address = create(:address, addressable: organization, street_address: "1 Plain St")

    expect(address.decorate.picker_label).to eq(address.name)
    expect(address.decorate.picker_label).not_to include("invoice address")
  end

  it "names the one marked for invoices" do
    address = create(:address, addressable: organization, street_address: "9 Billing Rd", invoice_address: true)

    expect(address.decorate.picker_label).to start_with(address.name)
    expect(address.decorate.picker_label).to include("invoice address")
  end
end
