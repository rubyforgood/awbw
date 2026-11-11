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

  shared_examples "counts the award at the training transferred into" do
    it "counts the origin's awards at the destination" do
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

  context "when the transfer moved to an earlier training" do
    let!(:registrations) { transfer(from: march, to: november) }
    let(:origin) { registrations.first }
    let(:destination) { registrations.last }

    it_behaves_like "counts the award at the training transferred into"
  end

  context "when the transfer moved to a later training" do
    let!(:registrations) { transfer(from: november, to: march, status: "registered") }
    let(:origin) { registrations.first }
    let(:destination) { registrations.last }

    it_behaves_like "counts the award at the training transferred into"
  end

  it "leaves awards at the original when the new registration was cancelled" do
    origin, = transfer(from: march, to: november, status: "cancelled")

    expect(described_class.new([ origin.id ]).award_registration_ids).to eq([ origin.id ])
  end

  it "leaves registrations without a transfer alone" do
    registration = create(:event_registration, event: march, registrant: person, status: "attended")

    expect(described_class.new([ registration.id ]).award_registration_ids).to eq([ registration.id ])
  end
end
