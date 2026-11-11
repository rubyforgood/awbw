require "rails_helper"

RSpec.describe ScholarshipDollarRegistrations do
  let(:person) { create(:person) }
  let(:march) { training(Time.zone.local(2027, 3, 18, 9)) }
  let(:november) { training(Time.zone.local(2026, 11, 5, 9)) }

  def training(start_date)
    create(:event, start_date: start_date, end_date: start_date + 2.days)
  end

  def transfer(from:, to:, status: "attended")
    origin = create(:event_registration, event: from, registrant: person, status: "transferred_out")
    destination = create(:event_registration, event: to, registrant: person, status: status, transferred_from_registration: origin)
    [ origin, destination ]
  end

  context "when the transfer moved to an earlier training" do
    let!(:registrations) { transfer(from: march, to: november) }
    let(:origin) { registrations.first }
    let(:destination) { registrations.last }

    it "counts the origin's awards at the earlier training" do
      expect(described_class.new([ destination.id ]).award_registration_ids).to contain_exactly(destination.id, origin.id)
      expect(described_class.new([ destination.id ]).counting_registration_id(origin.id)).to eq(destination.id)
    end

    it "takes them off the original training" do
      expect(described_class.new([ origin.id ]).award_registration_ids).to be_empty
    end

    it "counts them once when a report spans both trainings" do
      bulk = described_class.new([ origin.id, destination.id ])

      expect(bulk.award_registration_ids).to contain_exactly(origin.id, destination.id)
      expect(bulk.counting_registration_id(origin.id)).to eq(destination.id)
    end
  end

  it "leaves awards at the original when the transfer moved to a later training" do
    origin, destination = transfer(from: november, to: march)

    expect(described_class.new([ origin.id ]).award_registration_ids).to eq([ origin.id ])
    expect(described_class.new([ destination.id ]).award_registration_ids).to eq([ destination.id ])
  end

  it "leaves awards at the original when both trainings start the same day" do
    same_day = training(march.start_date + 3.hours)
    origin, = transfer(from: march, to: same_day)

    expect(described_class.new([ origin.id ]).award_registration_ids).to eq([ origin.id ])
  end

  it "leaves awards at the original when a training has no start date" do
    undated = training(november.start_date).tap { |event| event.update_columns(start_date: nil) }
    origin, = transfer(from: march, to: undated)

    expect(described_class.new([ origin.id ]).award_registration_ids).to eq([ origin.id ])
  end

  it "leaves awards at the original when the earlier registration was cancelled" do
    origin, = transfer(from: march, to: november, status: "cancelled")

    expect(described_class.new([ origin.id ]).award_registration_ids).to eq([ origin.id ])
  end
end
