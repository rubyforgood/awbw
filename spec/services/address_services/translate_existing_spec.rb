require "rails_helper"

RSpec.describe AddressServices::TranslateExisting do
  let(:us) { "United States" }

  # Stored as old rows hold them, past the model.
  def address_with(country:, state:, locality: Address::UNKNOWN_LOCALITY, city: "Springfield")
    create(:address, addressable: create(:person), city:).tap do |address|
      address.update_columns(country:, state:, locality:)
    end
  end

  def stored(address) = Address.where(id: address.id).pick(:country, :state, :locality)

  def answer(submission, identifier, value)
    field = create(:form_field, form: submission.form, field_identifier: identifier, name: identifier)
    create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
  end

  it "translates stored countries and states, reading a missing country from the state" do
    usa = address_with(country: "USA", state: "Texas")
    blank = address_with(country: nil, state: "CA - California")
    province = address_with(country: "-", state: "BC")
    russia = address_with(country: "Russian Federation", state: "Moscow")

    described_class.new.call

    expect(stored(usa).first(2)).to eq([ us, "TX" ])
    expect(stored(blank).first(2)).to eq([ us, "CA" ])
    expect(stored(province).first(2)).to eq([ "Canada", "BC" ])
    expect(stored(russia).first).to eq("Russia")
  end

  it "fills a locality only where it's Unknown" do
    unknown = address_with(country: nil, state: "MA", city: "Cambridge")
    chosen = address_with(country: nil, state: "CA", city: "Fresno", locality: "Central CA")

    described_class.new.call

    expect(stored(unknown).last).to eq(Address::OUTSIDE_CA)
    expect(stored(chosen).last).to eq("Central CA")
  end

  it "clears a placeholder country when the state names none" do
    dash = address_with(country: "-", state: "Central Region")
    unknown = address_with(country: "unknown", state: "-")

    described_class.new.call

    expect([ stored(dash).first, stored(unknown).first ]).to eq([ nil, nil ])
  end

  it "clears a country it can't place, logging what it was and reporting it" do
    narnia = address_with(country: "Narnia", state: "Central Region")

    result = described_class.new.call

    expect(stored(narnia).first).to be_nil
    expect(result.unmatched[:country]).to include("Narnia" => 1)
    expect(Ahoy::Event.find_by!(name: "autochange.address", resource_id: narnia.id).properties["changes"])
      .to include("country" => { "before" => "Narnia", "after" => nil })
  end

  it "leaves form answers exactly as people typed them" do
    submission = create(:form_submission)
    typed = { "mailing_state" => "California", "mailing_country" => "USA",
              "organization_country" => "Untied States", "organization_state" => "Texas" }
    answers = typed.to_h { |identifier, value| [ identifier, answer(submission, identifier, value) ] }

    expect { described_class.new.call }.not_to change(Ahoy::Event.where(name: "autochange.form_answer"), :count)

    expect(answers.transform_values { _1.reload.submitted_answer }).to eq(typed)
  end

  it "leaves every stored address country on the dropdown" do
    address_with(country: "Narnia", state: "Central Region")
    address_with(country: "USA", state: "TX")

    described_class.new.call

    expect(Address.where.not(country: [ nil, "" ]).pluck(:country) - GeographyHelper::COUNTRIES).to be_empty
  end

  it "logs each changed address as one autochange event, all in one visit" do
    usa = address_with(country: "USA", state: "TX", locality: Address::OUTSIDE_CA)
    texas = address_with(country: nil, state: "Texas", locality: Address::OUTSIDE_CA)

    expect { described_class.new.call }.to change(Ahoy::Event, :count).by(2)

    address_event = Ahoy::Event.find_by!(name: "autochange.address", resource_id: usa.id)
    expect(address_event.properties).to include("changes" => { "country" => { "before" => "USA", "after" => us } },
                                                "reason" => "address_translation")
    expect(Ahoy::Event.where(name: "autochange.address", resource_id: [ usa.id, texas.id ]).distinct.count(:visit_id)).to eq(1)
  end

  it "lists every address change with its owner and before/after, on a dry run too" do
    usa = address_with(country: "USA", state: "Texas", locality: Address::OUTSIDE_CA)
    org_address = create(:address, addressable: create(:organization)).tap { |address| address.update_columns(country: "Usa", state: "TX", locality: Address::OUTSIDE_CA) }

    rows = described_class.new(dry_run: true).call.rows

    expect(rows).to contain_exactly(
      have_attributes(address_id: usa.id, person_id: usa.addressable_id, organization_id: nil,
                      field: :country, before: "USA", after: "United States"),
      have_attributes(address_id: usa.id, field: :state, before: "Texas", after: "TX"),
      have_attributes(address_id: org_address.id, person_id: nil, organization_id: org_address.addressable_id,
                      field: :country, before: "Usa", after: "United States")
    )
  end

  it "writes and logs nothing on a dry run, but reports what it would change" do
    usa = address_with(country: "USA", state: "TX")

    result = nil
    expect { result = described_class.new(dry_run: true).call }.not_to change { [ Ahoy::Event.count, Ahoy::Visit.count ] }

    expect(stored(usa).first).to eq("USA")
    expect(result.changes).to include("Address country: \"USA\" → \"United States\"" => 1)
  end

  it "changes nothing the second time" do
    address_with(country: "USA", state: "Texas")

    described_class.new.call

    expect { described_class.new.call }.not_to change(Ahoy::Event, :count)
  end
end
