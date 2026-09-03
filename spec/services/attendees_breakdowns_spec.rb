require "rails_helper"

RSpec.describe AttendeesBreakdowns do
  let(:person) { create(:person) }
  let!(:training) { create(:event, facilitator_training: true, start_date: Date.new(2025, 5, 1)) }
  let!(:registration) { create(:event_registration, event: training, registrant: person, status: "attended") }

  # Built from a fresh relation like the controller passes it.
  subject(:breakdowns) { described_class.new(Person.where(id: person.id)) }

  it "reports the filtered person count" do
    expect(breakdowns.registrant_count).to eq(1)
  end

  it "counts distinct people per primary sector, from their profile" do
    sector = create(:sector, name: "Healthcare")
    create(:sectorable_item, sectorable: person, sector: sector, is_primary: true)
    expect(breakdowns.primary_sector_counts).to eq(sector.id => 1)
    expect(breakdowns.sector_counts).to eq(sector.id => 1)
  end

  it "counts US states from active addresses" do
    create(:address, addressable: person, state: "CA", inactive: false)
    expect(breakdowns.state_counts).to eq("CA" => 1)
  end

  it "aggregates organizations linked on the person's training registrations" do
    organization = create(:organization, name: "Wellness Org")
    registration.event_registration_organizations.create!(organization: organization)
    expect(breakdowns.organizations).to include(organization)
    expect(breakdowns.organization_counts).to eq(organization.id => 1)
  end

  it "groups attendees by the city of the org linked on their training registration" do
    organization = create(:organization, name: "Wellness Org")
    create(:address, addressable: organization, city: "Austin", state: "TX", inactive: false)
    registration.event_registration_organizations.create!(organization: organization)

    rows = breakdowns.registrant_city_breakdown.rows
    expect(rows.map(&:city)).to eq([ "Austin, TX" ])
    expect(rows.first.registrant_count).to eq(1)
  end

  it "counts scholarship recipients and CE registrants across training registrations" do
    scholarship = create(:scholarship, recipient: person, amount_cents: 1_000)
    create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)
    create(:continuing_education_registration, event_registration: registration)

    expect(breakdowns.scholarship_recipient_count).to eq(1)
    expect(breakdowns.ce_registrant_ids).to eq([ person.id ])
  end

  it "leaves a declined award out of the recipient counts (matching EventDashboard)" do
    scholarship = create(:scholarship, recipient: person, amount_cents: 1_000)
    create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)
    scholarship.reload.decline_agreement!("Timing no longer works")

    expect(breakdowns.scholarship_recipient_count).to eq(0)
    expect(breakdowns.scholarship_registrant_ids).to be_empty
    expect(breakdowns.registrant_city_breakdown.rows.sum(&:scholarship_count)).to eq(0)
  end

  it "classifies program status without a per-org affiliations query" do
    people = 3.times.map do
      registrant = create(:person)
      reg = create(:event_registration, event: training, registrant: registrant, status: "attended")
      org = create(:organization)
      create(:affiliation, organization: org, person: registrant, title: "Facilitator", start_date: 1.year.ago)
      reg.event_registration_organizations.create!(organization: org)
      registrant
    end
    breakdowns = described_class.new(Person.where(id: people.map(&:id)))

    affiliation_queries = 0
    counter = ->(_name, _start, _finish, _id, payload) do
      affiliation_queries += 1 if payload[:sql].to_s.include?("FROM `affiliations`")
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      breakdowns.program_status_counts
    end

    # Orgs' affiliations preloaded in one query, not one-per-org.
    expect(affiliation_queries).to be <= 1
  end

  # The breakdown rows drill in by person id on the roster and recipients pages,
  # so each dimension exposes the people behind it. These regroup rows already
  # loaded for the counts — asking for both must not cost a second query.
  describe "referral source (how did you hear about this AWBW training?)" do
    let(:registration_form) { create(:form, name: "Registration") }
    let!(:referral_field) do
      field = create(:form_field, form: registration_form, field_identifier: FormField::REFERRAL_SOURCE_FIELD_IDENTIFIER,
                                  name: "How did you hear about this AWBW training?", answer_type: :single_select_radio)
      create(:form_field_answer_option, form_field: field, answer_option: create(:answer_option, name: "Online Search"))
      create(:form_field_answer_option, form_field: field, answer_option: create(:answer_option, name: "Other"))
      field
    end
    let!(:other_training) { create(:event, facilitator_training: true, start_date: Date.new(2025, 6, 1)) }

    def answer(who, event, value)
      submission = create(:form_submission, person: who, form: registration_form, event: event)
      create(:form_answer, form_field: referral_field, submitted_answer: value, form_submission: submission)
    end

    it "counts distinct people per answer across the scoped events, collapsing specify answers" do
      p2 = create(:person)
      create(:event_registration, event: training, registrant: p2, status: "attended")

      answer(person, training, "Online Search")
      answer(person, other_training, "Online Search") # same person + answer, other event → counted once
      answer(p2, training, "Online Search")
      answer(p2, other_training, "Other: Facebook")   # collapses to "Other"

      bd = described_class.new(Person.where(id: [ person.id, p2.id ]))
      expect(bd.referral_source_counts).to eq([ [ "Online Search", 2 ], [ "Other", 1 ] ])
    end

    it "ignores answers on events outside the scoped set" do
      answer(person, training, "Online Search")
      answer(person, other_training, "Social Media")

      bd = described_class.new(Person.where(id: person.id), events: Event.where(id: training.id))
      expect(bd.referral_source_counts).to eq([ [ "Online Search", 1 ] ])
    end
  end

  describe "person ids per row" do
    it "returns the people behind each dimension" do
      sector = create(:sector, name: "Healthcare")
      create(:sectorable_item, sectorable: person, sector: sector, is_primary: true)
      create(:address, addressable: person, state: "CA", inactive: false)
      organization = create(:organization, name: "Wellness Org")
      registration.event_registration_organizations.create!(organization: organization)
      scholarship = create(:scholarship, recipient: person, amount_cents: 1_000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)

      expect(breakdowns.primary_sector_registrant_ids_by_sector[sector.id]).to eq([ person.id ])
      expect(breakdowns.sector_registrant_ids_by_sector[sector.id]).to eq([ person.id ])
      expect(breakdowns.state_registrant_ids_by_state["CA"]).to eq([ person.id ])
      expect(breakdowns.organization_registrant_ids_by_org[organization.id]).to eq([ person.id ])
      expect(breakdowns.scholarship_registrant_ids).to eq([ person.id ])
      expect(breakdowns.registrant_ids).to eq([ person.id ])
    end

    it "shares one query with the matching counts" do
      counts_only = described_class.new(Person.where(id: person.id))
      with_ids = described_class.new(Person.where(id: person.id))

      counts = count_queries { counts_only.state_counts; counts_only.country_counts; counts_only.school_district_counts }
      both = count_queries do
        with_ids.state_counts
        with_ids.country_counts
        with_ids.school_district_counts
        with_ids.state_registrant_ids_by_state
        with_ids.country_registrant_ids_by_country
        with_ids.school_district_registrant_ids_by_district
      end

      expect(both).to eq(counts)
    end
  end

  def count_queries
    queries = 0
    counter = ->(_name, _start, _finish, _id, payload) do
      queries += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    queries
  end
end
