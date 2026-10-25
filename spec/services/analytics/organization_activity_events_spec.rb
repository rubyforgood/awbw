require "rails_helper"

RSpec.describe Analytics::OrganizationActivityEvents do
  let(:organization) { create(:organization) }

  def event(resource_type:, resource_id:, name:, attributes: nil)
    properties = { "resource_type" => resource_type, "resource_id" => resource_id }
    properties["attributes"] = attributes if attributes
    create(:ahoy_event, name: name, resource_type: resource_type, resource_id: resource_id, properties: properties)
  end

  def deleted_address(id, owner_type, owner_id)
    event(resource_type: "Address", resource_id: id, name: "destroy.address",
          attributes: { "addressable_type" => owner_type, "addressable_id" => owner_id })
  end

  it "includes events about the organization and its current addresses" do
    address = create(:address, addressable: organization)
    own = event(resource_type: "Organization", resource_id: organization.id, name: "update.organization")
    address_update = event(resource_type: "Address", resource_id: address.id, name: "update.address")

    expect(described_class.new(organization).relation).to include(own, address_update)
  end

  it "includes a deleted address's whole history, found through its delete snapshot" do
    created = event(resource_type: "Address", resource_id: 9_301, name: "create.address")
    destroyed = deleted_address(9_301, "Organization", organization.id)

    expect(described_class.new(organization).relation).to include(created, destroyed)
  end

  it "leaves out addresses deleted from another organization or a person with the same id" do
    other_org = deleted_address(9_302, "Organization", organization.id + 1)
    person = deleted_address(9_303, "Person", organization.id)

    expect(described_class.new(organization).relation).not_to include(other_org, person)
  end
end
