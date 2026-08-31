# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventRegistrationServices::DuplicateFinder do
  let(:event) { create(:event) }

  def registration(attrs = {})
    registration_event = attrs.delete(:event) || event
    create(:event_registration,
      event: registration_event,
      registrant: create(:person, { user: nil }.merge(attrs)))
  end

  describe "#groups" do
    it "groups same-event registrations whose registrants share a name" do
      a = registration(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
      b = registration(first_name: "Jane", last_name: "Doe", email: "jane.doe@work.com")
      registration(first_name: "Unrelated", last_name: "Person", email: "u@example.com")

      groups = described_class.new.groups

      expect(groups.size).to eq(1)
      expect(groups.first.records).to contain_exactly(a, b)
      expect(groups.first.reasons).to include("Same registrant name")
    end

    it "matches a nickname or legal-name variant of the registrant's first name" do
      a = registration(first_name: "Bob", last_name: "Smith", email: "bob@example.com")
      b = registration(first_name: "Robert", last_name: "Smith", email: "robert@example.com")

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b)
      expect(group.reasons).to include("Same registrant name")
    end

    it "groups registrations whose registrants share an email address" do
      a = registration(first_name: "Chris", last_name: "Alpha", email: "shared@example.com")
      b = registration(first_name: "Kris", last_name: "Beta", email: "SHARED@example.com")

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b)
      expect(group.reasons).to include("Shared registrant email")
    end

    it "matches an email stored in the registrant's secondary email_2 field" do
      a = registration(first_name: "Dana", last_name: "Gamma", email: "dana@primary.com")
      b = registration(first_name: "Dana", last_name: "Delta", email: "dana@other.com", email_2: "dana@primary.com")

      expect(described_class.new.groups.first.records).to contain_exactly(a, b)
    end

    it "groups registrations whose registrants share a FileMaker code" do
      a = registration(first_name: "Erin", last_name: "One", email: "e1@example.com", filemaker_code: "FM777")
      b = registration(first_name: "Erin", last_name: "Two", email: "e2@example.com", filemaker_code: "FM777")

      group = described_class.new.groups.first

      expect(group.records).to contain_exactly(a, b)
      expect(group.reasons).to include("Same registrant FileMaker code (FM777)")
    end

    it "flags different FileMaker codes on registrants grouped by another signal" do
      registration(first_name: "Fay", last_name: "Nguyen", email: "fay@example.com", filemaker_code: "FM1")
      registration(first_name: "Fay", last_name: "Nguyen", email: "fay2@example.com", filemaker_code: "FM2")

      expect(described_class.new.groups.first.reasons)
        .to include(a_string_matching(/Different FileMaker codes \(FM1, FM2\)/))
    end

    it "does not group the same person registered for different events" do
      person = create(:person, first_name: "Same", last_name: "Person", email: "same@example.com", user: nil)
      create(:event_registration, event: event, registrant: person)
      create(:event_registration, event: create(:event), registrant: person)

      expect(described_class.new.groups).to be_empty
    end

    it "returns nothing when there are no duplicates" do
      registration(first_name: "Only", last_name: "One", email: "only@example.com")

      expect(described_class.new.groups).to be_empty
    end
  end
end
