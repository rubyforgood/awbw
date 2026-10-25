require "rails_helper"

RSpec.describe MergeDuplicateAddressesJob, type: :job do
  let(:attrs) do
    {
      street_address: "1 Main St", city: "Springfield", state: "CA", zip_code: "90001",
      country: "USA", county: "LA", district: nil, address_type: "work", locality: "LA City"
    }
  end
  let(:org) { create(:organization) }
  let(:person) { create(:person) }

  before do
    create_list(:address, 2, addressable: org, **attrs)
    create_list(:address, 3, addressable: person, **attrs, street_address: "1 Main Street")
  end

  it "merges every record's duplicate addresses" do
    described_class.new.perform

    expect(org.addresses.count).to eq(1)
    expect(person.addresses.count).to eq(1)
  end

  it "logs each merged-away address to the owner's activity as the admin who ran it" do
    admin = create(:user, :admin)
    merged_away = person.addresses.order(:id).drop(1).map(&:id)

    described_class.new.perform(admin)

    events = Ahoy::Event.where(name: "destroy.address", resource_id: merged_away)
    expect(events.pluck(:user_id)).to eq([ admin.id, admin.id ])
    expect(events.map { |event| event.properties["source"] }.uniq).to eq([ MergeDuplicateAddressesJob::SOURCE ])
    expect(Analytics::PersonActivityEvents.new(person).relation).to include(*events)
  end

  it "reports a record that fails and keeps merging the rest" do
    allow(AddressDeduper).to receive(:merge_duplicates).and_call_original
    allow(AddressDeduper).to receive(:merge_duplicates).with(org).and_raise("boom")
    allow(Rails.error).to receive(:report)

    described_class.new.perform

    expect(Rails.error).to have_received(:report).with(an_instance_of(RuntimeError), context: { addressable: org.to_global_id.to_s })
    expect(org.addresses.count).to eq(2)
    expect(person.addresses.count).to eq(1)
  end

  it "allows only one run at a time" do
    expect(described_class.concurrency_limit).to eq(1)
    expect(described_class.concurrency_on_conflict).to eq(:discard)
  end
end
