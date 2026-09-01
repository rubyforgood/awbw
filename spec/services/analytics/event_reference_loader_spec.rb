require "rails_helper"

RSpec.describe Analytics::EventReferenceLoader do
  def event(properties)
    build(:ahoy_event, properties: properties)
  end

  describe ".reference?" do
    it "recognizes a bare type + id reference" do
      expect(described_class.reference?({ "type" => "Workshop", "id" => 1, "action" => "added" })).to be(true)
      expect(described_class.reference?({ "record_type" => "Sector", "record_id" => 2 })).to be(true)
    end

    it "rejects named entities and attribute snapshots" do
      expect(described_class.reference?({ "id" => 1, "name" => "Education" })).to be(false)
      expect(described_class.reference?({ "title" => "A workshop", "published" => true })).to be(false)
    end
  end

  describe "#records" do
    it "loads every referenced record across events into a { [type, id] => record } map" do
      workshop = create(:workshop)
      sector = create(:sector)

      events = [
        event("association_changes" => { "workshops" => [ { "action" => "added", "id" => workshop.id, "type" => "Workshop" } ] }),
        event("associated_records" => [ { "record_type" => "Sector", "record_id" => sector.id } ])
      ]

      map = described_class.new(events).records

      expect(map[[ "Workshop", workshop.id ]]).to eq(workshop)
      expect(map[[ "Sector", sector.id ]]).to eq(sector)
    end

    it "loads each event's own resource from its resource_type/resource_id columns" do
      workshop = create(:workshop)
      events = [ build(:ahoy_event, resource_type: "Workshop", resource_id: workshop.id, properties: {}) ]

      map = described_class.new(events).records

      expect(map[[ "Workshop", workshop.id ]]).to eq(workshop)
    end

    it "omits records that no longer exist" do
      events = [ event("associated_records" => [ { "record_type" => "Workshop", "record_id" => 0 } ]) ]
      expect(described_class.new(events).records).to eq({})
    end

    it "issues one query per referenced type, not one per reference" do
      workshops = create_list(:workshop, 3)
      events = workshops.map do |w|
        event("association_changes" => { "workshops" => [ { "action" => "added", "id" => w.id, "type" => "Workshop" } ] })
      end
      loader = described_class.new(events)

      workshop_selects = 0
      counter = ->(_n, _s, _f, _i, payload) do
        workshop_selects += 1 if payload[:sql]&.include?("`workshops`")
      end

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { loader.records }

      expect(workshop_selects).to eq(1)
    end
  end
end
