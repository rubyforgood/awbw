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

  describe "#relation" do
    it "includes events about the organization and its associated records" do
      affiliation = create(:affiliation, organization: organization)
      link = create(:event_registration_organization, organization: organization)
      story = create(:story, organization: organization)
      report = create(:monthly_report, organization: organization)
      events = [
        event(resource_type: "Organization", resource_id: organization.id, name: "update.organization"),
        event(resource_type: "Affiliation", resource_id: affiliation.id, name: "update.affiliation"),
        event(resource_type: "EventRegistrationOrganization", resource_id: link.id, name: "create.event_registration_organization"),
        event(resource_type: "EventRegistration", resource_id: link.event_registration_id, name: "update.event_registration"),
        event(resource_type: "Story", resource_id: story.id, name: "update.story"),
        event(resource_type: "MonthlyReport", resource_id: report.id, name: "update.report")
      ]

      expect(described_class.new(organization).relation).to include(*events)
    end

    it "includes a deleted affiliation's history and a deleted link's registration" do
      created = event(resource_type: "Affiliation", resource_id: 9_401, name: "create.affiliation")
      destroyed = event(resource_type: "Affiliation", resource_id: 9_401, name: "destroy.affiliation",
                        attributes: { "organization_id" => organization.id })
      event(resource_type: "EventRegistrationOrganization", resource_id: 9_402, name: "destroy.event_registration_organization",
            attributes: { "organization_id" => organization.id, "event_registration_id" => 9_403 })
      registration = event(resource_type: "EventRegistration", resource_id: 9_403, name: "update.event_registration")

      expect(described_class.new(organization).relation).to include(created, destroyed, registration)
    end

    it "leaves out another organization's records" do
      other = create(:organization)
      story = create(:story, organization: other)
      other_story = event(resource_type: "Story", resource_id: story.id, name: "update.story")
      other_affiliation = event(resource_type: "Affiliation", resource_id: 9_404, name: "destroy.affiliation",
                                attributes: { "organization_id" => other.id })

      expect(described_class.new(organization).relation).not_to include(other_story, other_affiliation)
    end
  end

  describe "#change_log" do
    it "includes events about the organization and its current addresses" do
      address = create(:address, addressable: organization)
      own = event(resource_type: "Organization", resource_id: organization.id, name: "update.organization")
      address_update = event(resource_type: "Address", resource_id: address.id, name: "update.address")

      expect(described_class.new(organization).change_log).to include(own, address_update)
    end

    it "includes a deleted address's whole history, found through its delete snapshot" do
      created = event(resource_type: "Address", resource_id: 9_301, name: "create.address")
      destroyed = deleted_address(9_301, "Organization", organization.id)

      expect(described_class.new(organization).change_log).to include(created, destroyed)
    end

    it "leaves out addresses deleted from another organization or a person with the same id" do
      other_org = deleted_address(9_302, "Organization", organization.id + 1)
      person = deleted_address(9_303, "Person", organization.id)

      expect(described_class.new(organization).change_log).not_to include(other_org, person)
    end

    it "leaves out the organization's associated records" do
      affiliation = create(:affiliation, organization: organization)
      affiliation_update = event(resource_type: "Affiliation", resource_id: affiliation.id, name: "update.affiliation")

      expect(described_class.new(organization).change_log).not_to include(affiliation_update)
    end
  end
end
