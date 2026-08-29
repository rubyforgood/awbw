# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContactMethod do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let(:contact_method) do
    create(:contact_method, contactable: person, kind: "phone", value: "555-010-1010")
  end

  before do
    Current.user = admin
  end

  after do
    Current.reset
  end

  describe "#timeline_label" do
    it "is generic, without the value" do
      expect(contact_method.timeline_label).to eq("Phone")
    end
  end

  describe "timeline events" do
    it "records a created event with the generic label" do
      contact_method

      event = person.timeline_events.where(subject_type: "ContactMethod", action: "created").sole
      expect(event.snapshot["label"]).to eq("Phone")
      expect(event.snapshot["changes"]).to eq({})
    end

    it "records an updated event without the change details" do
      contact_method

      contact_method.update!(value: "555-020-2020")

      event = person.timeline_events.where(subject_type: "ContactMethod", action: "updated").sole
      expect(event.subject&.timeline_label).to eq("Phone")
      expect(event.snapshot["changes"]).to eq({})
    end
  end
end
