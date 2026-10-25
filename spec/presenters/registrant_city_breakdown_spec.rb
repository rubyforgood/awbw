require "rails_helper"

RSpec.describe RegistrantCityBreakdown do
  describe "#rows" do
    it "counts distinct registrants and scholarship recipients per city, most first" do
      breakdown = described_class.new(
        city_registrant_pairs: [ [ "Los Angeles, CA", 10 ], [ "Los Angeles, CA", 11 ], [ "Richmond, CA", 12 ] ],
        scholarship_recipient_ids: [ 10 ]
      )

      expect(breakdown.rows.map { |r| [ r.city, r.registrant_count, r.scholarship_count ] }).to eq(
        [ [ "Los Angeles, CA", 2, 1 ], [ "Richmond, CA", 1, 0 ] ]
      )
    end

    it "exposes per-city registrant and scholarship-recipient ids for drill-in links" do
      breakdown = described_class.new(
        city_registrant_pairs: [ [ "Los Angeles, CA", 10 ], [ "Los Angeles, CA", 11 ], [ "Richmond, CA", 12 ] ],
        scholarship_recipient_ids: [ 10, 12 ]
      )

      la = breakdown.rows.find { |r| r.city == "Los Angeles, CA" }
      expect(la.registrant_ids).to contain_exactly(10, 11)
      expect(la.scholarship_recipient_ids).to contain_exactly(10)
    end

    it "counts a registrant once per city even when listed there twice" do
      breakdown = described_class.new(
        city_registrant_pairs: [ [ "Barstow, CA", 10 ], [ "Barstow, CA", 10 ] ],
        scholarship_recipient_ids: []
      )

      expect(breakdown.rows.map(&:registrant_count)).to eq([ 1 ])
    end

    it "buckets a nil city under Unknown, sorted last" do
      breakdown = described_class.new(
        city_registrant_pairs: [ [ "Perris, CA", 10 ], [ "Perris, CA", 11 ], [ nil, 12 ] ],
        scholarship_recipient_ids: []
      )

      expect(breakdown.rows.map { |r| [ r.city, r.registrant_count ] }).to eq(
        [ [ "Perris, CA", 2 ], [ "Unknown", 1 ] ]
      )
    end
  end

  it "reports city_count and any?" do
    breakdown = described_class.new(
      city_registrant_pairs: [ [ "Pomona, CA", 10 ], [ "Tustin, CA", 11 ] ],
      scholarship_recipient_ids: []
    )

    expect(breakdown.city_count).to eq(2)
    expect(breakdown).to be_any
    expect(described_class.new(city_registrant_pairs: [], scholarship_recipient_ids: [])).not_to be_any
  end
end
