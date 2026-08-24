# frozen_string_literal: true

require "rails_helper"

RSpec.describe Timelineable do
  let(:admin) { create(:user, :admin) }

  before do
    Current.user = admin
  end

  after do
    Current.reset
  end

  describe "create" do
    it "records a created event on the person's timeline" do
      person = create(:person)

      event = person.timeline_events.sole
      expect(event.action).to eq("created")
      expect(event.actor).to eq(admin)
      expect(event.timeline_entries.sole.owner).to eq(person)
      expect(event.subject_label).to eq(person.name)
    end

    it "labels a userless actor from Current.source" do
      Current.user = nil
      Current.source = "public_registration"

      person = create(:person)

      event = person.timeline_events.sole
      expect(event.actor).to be_nil
      expect(event.actor_label).to eq("Registrant")
    end
  end

  describe "update" do
    it "records an updated event with the changes" do
      person = create(:person)
      old_first_name = person.first_name

      person.update!(first_name: "Renamed")

      event = person.timeline_events.where(action: "updated").sole
      expect(event.snapshot["changes"]["first_name"]).to eq([ old_first_name.to_s, "Renamed" ])
      expect(event.snapshot["changes"]).not_to include("updated_at")
    end

    it "records nothing when only noise columns changed" do
      person = create(:person)

      expect { person.touch }.not_to change(TimelineEvent, :count)
    end
  end

  describe "suppression" do
    it "records nothing while suppressed" do
      expect {
        TimelineServices::RecordEvent.suppress { create(:person) }
      }.not_to change(TimelineEvent, :count)
    end
  end
end
