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

  it "blanks a country answer it can't place" do
    submission = create(:form_submission)
    answer(submission, "mailing_state", "-")
    country = answer(submission, "mailing_country", "West Africa")

    described_class.new.call

    expect(country.reload.submitted_answer).to eq("")
  end

  it "leaves every stored country and country answer on the dropdown" do
    address_with(country: "Narnia", state: "Central Region")
    address_with(country: "USA", state: "TX")
    submission = create(:form_submission)
    answer(submission, "organization_country", "Atlantis")

    described_class.new.call

    expect(Address.where.not(country: [ nil, "" ]).pluck(:country) - GeographyHelper::COUNTRIES).to be_empty
    expect(FormAnswer.where.not(submitted_answer: [ nil, "" ]).pluck(:submitted_answer) - GeographyHelper::COUNTRIES).to be_empty
  end

  it "translates country and state answers using the submission's other answer" do
    submission = create(:form_submission)
    answer(submission, "mailing_state", "California")
    country = answer(submission, "mailing_country", "")
    org_country = answer(submission, "organization_country", "Untied States")
    org_state = answer(submission, "organization_state", "Texas")

    described_class.new.call

    expect(country.reload.submitted_answer).to eq(us)
    expect(org_country.reload.submitted_answer).to eq(us)
    expect(org_state.reload.submitted_answer).to eq("TX")
    expect(FormAnswer.joins(:form_field).find_by(form_fields: { field_identifier: "mailing_state" }).submitted_answer).to eq("CA")
  end

  it "leaves a blank answer blank when its section was skipped" do
    submission = create(:form_submission)
    org_country = answer(submission, "organization_country", "")

    described_class.new.call

    expect(org_country.reload.submitted_answer).to eq("")
  end

  it "logs each changed record as one autochange event, all in one visit" do
    usa = address_with(country: "USA", state: "TX", locality: Address::OUTSIDE_CA)
    submission = create(:form_submission)
    answer(submission, "mailing_state", "TX")
    country = answer(submission, "mailing_country", "USA")

    expect { described_class.new.call }.to change(Ahoy::Event, :count).by(2)

    address_event = Ahoy::Event.find_by!(name: "autochange.address", resource_id: usa.id)
    expect(address_event.properties).to include("changes" => { "country" => { "before" => "USA", "after" => us } },
                                                "reason" => "address_translation")
    answer_event = Ahoy::Event.find_by!(name: "autochange.form_answer", resource_id: country.id)
    expect(answer_event.properties["changes"]).to eq("submitted_answer" => { "before" => "USA", "after" => us })
    expect(Ahoy::Event.where(name: %w[autochange.address autochange.form_answer]).distinct.count(:visit_id)).to eq(1)
  end

  it "stamps each changed record with who made the change and when" do
    user = create(:user)
    usa = address_with(country: "USA", state: "TX", locality: Address::OUTSIDE_CA)
    usa.update_columns(updated_at: 1.day.ago)
    submission = create(:form_submission)
    answer(submission, "mailing_state", "TX")
    country = answer(submission, "mailing_country", "USA")

    described_class.new(user:).call

    expect(usa.reload.updated_by).to eq(user)
    expect(usa.updated_at).to be_within(1.minute).of(Time.current)
    expect(country.reload.updated_by).to eq(user)
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
