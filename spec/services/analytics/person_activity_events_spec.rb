require "rails_helper"

RSpec.describe Analytics::PersonActivityEvents do
  let(:person) { create(:person) }
  let(:visit) { create(:ahoy_visit) }

  def event(resource_type:, resource_id:, name: "update.record", properties: {})
    create(
      :ahoy_event,
      visit: visit,
      name: name,
      resource_type: resource_type,
      resource_id: resource_id,
      properties: { "resource_type" => resource_type, "resource_id" => resource_id }.merge(properties)
    )
  end

  describe "#relation" do
    it "includes events about the person record" do
      target = event(resource_type: "Person", resource_id: person.id, name: "update.person")
      expect(described_class.new(person).relation).to include(target)
    end

    it "includes lifecycle events about the person's user account" do
      target = event(resource_type: "User", resource_id: person.user.id, name: "update.user")
      expect(described_class.new(person).relation).to include(target)
    end

    it "includes auth events for the person's user (matched via JSON record_id)" do
      target = create(
        :ahoy_event,
        visit: visit,
        name: "auth.login",
        resource_type: nil,
        resource_id: nil,
        properties: { "record_id" => person.user.id, "record_type" => "User" }
      )
      expect(described_class.new(person).relation).to include(target)
    end

    it "includes events about associated data (e.g. the person's payments)" do
      payment = create(:payment, person: person)
      target = event(resource_type: "Payment", resource_id: payment.id, name: "create.payment")
      expect(described_class.new(person).relation).to include(target)
    end

    it "includes events about the person's continuing education registrations" do
      registration = create(:event_registration, registrant: person)
      ce = create(:continuing_education_registration, event_registration: registration)
      target = event(resource_type: "ContinuingEducationRegistration", resource_id: ce.id,
                     name: "update.continuing_education_registration")
      expect(described_class.new(person).relation).to include(target)
    end

    it "includes events about comments connected to the person's associated records" do
      scholarship = create(:scholarship, recipient: person)
      comment = create(:comment, commentable: scholarship)
      target = event(resource_type: "Comment", resource_id: comment.id, name: "create.comment")
      expect(described_class.new(person).relation).to include(target)
    end

    it "excludes events unrelated to the person" do
      unrelated_person = create(:person)
      other = event(resource_type: "Person", resource_id: unrelated_person.id, name: "update.person")
      auth_for_other = create(
        :ahoy_event,
        visit: visit,
        name: "auth.login",
        properties: { "record_id" => unrelated_person.user.id, "record_type" => "User" }
      )

      relation = described_class.new(person).relation
      expect(relation).not_to include(other)
      expect(relation).not_to include(auth_for_other)
    end

    it "returns no events when the person has none" do
      event(resource_type: "Workshop", resource_id: 999, name: "view.workshop")
      expect(described_class.new(person).relation).to be_empty
    end
  end

  describe "#count" do
    it "counts the person's, their user's, and associated data's events" do
      event(resource_type: "Person", resource_id: person.id, name: "update.person")
      event(resource_type: "User", resource_id: person.user.id, name: "update.user")
      payment = create(:payment, person: person)
      event(resource_type: "Payment", resource_id: payment.id, name: "create.payment")
      event(resource_type: "Person", resource_id: create(:person).id, name: "update.person")

      expect(described_class.new(person).count).to eq(3)
    end
  end
end
