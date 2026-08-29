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
    end

    it "keeps per-field change details while the label stays generic" do
      contact_method

      expect { contact_method.update!(value: "555-020-2020") }
        .to change { person.timeline_events.where(subject_type: "ContactMethod", action: "updated").count }.by(1)

      event = person.timeline_events.where(subject_type: "ContactMethod", action: "updated").sole
      expect(event.snapshot["label"]).to eq("Phone")
      expect(event.snapshot["changes"]["value"]).to eq([ "555-010-1010", "555-020-2020" ])
    end
  end
end
