require "rails_helper"

RSpec.describe Analytics::PersonTimeline do
  describe "#entries" do
    it "merges events and communications into one timeline, newest first" do
      older_event = build_stubbed(:ahoy_event, time: 3.days.ago)
      newer_event = build_stubbed(:ahoy_event, time: 1.hour.ago)
      middle_comm = build_stubbed(:notification, created_at: 1.day.ago)

      entries = described_class.new(
        events: [ older_event, newer_event ],
        communications: [ middle_comm ]
      ).entries

      expect(entries.map(&:record)).to eq([ newer_event, middle_comm, older_event ])
    end

    it "tags each entry with its kind" do
      event = build_stubbed(:ahoy_event, time: 1.hour.ago)
      comm = build_stubbed(:notification, created_at: 2.hours.ago)

      entries = described_class.new(events: [ event ], communications: [ comm ]).entries

      expect(entries.find(&:communication?).record).to eq(comm)
      expect(entries.reject(&:communication?).map(&:record)).to eq([ event ])
    end

    it "uses event#time and notification#created_at as the sort key" do
      event = build_stubbed(:ahoy_event, time: 5.minutes.ago)
      comm = build_stubbed(:notification, created_at: 10.minutes.ago)

      entries = described_class.new(events: [ event ], communications: [ comm ]).entries

      expect(entries.map(&:occurred_at)).to eq([ event.time, comm.created_at ])
    end

    it "handles empty streams" do
      expect(described_class.new(events: [], communications: []).entries).to eq([])
    end
  end
end
