require "rails_helper"

RSpec.describe EventProgramStatusReport do
  def training(title, start_date)
    create(:event, title: title, abbreviation: title.parameterize.upcase.first(6),
                   facilitator_training: true, start_date: start_date, end_date: start_date)
  end

  def represent(organization, event, status: "registered")
    registration = create(:event_registration, event: event, registrant: create(:person), status: status)
    registration.event_registration_organizations.create!(organization: organization)
    registration
  end

  def facilitator_since(organization, start_date, end_date = nil)
    create(:affiliation, organization: organization, person: create(:person),
                         title: "Facilitator", start_date: start_date, end_date: end_date)
  end

  let(:spring) { training("Spring Training", Date.new(2026, 3, 1)) }
  let(:fall) { training("Fall Training", Date.new(2026, 9, 1)) }
  let(:report) { described_class.new([ spring, fall ].map(&:decorate)) }

  describe "per training" do
    let(:brand_new) { create(:organization, name: "Brand New") }
    let(:established) { create(:organization, name: "Established") }
    let(:lapsed) { create(:organization, name: "Lapsed") }

    before do
      # Its first facilitator affiliation is minted by the training itself.
      facilitator_since(brand_new, spring.start_date)
      facilitator_since(established, Date.new(2019, 5, 1))
      facilitator_since(lapsed, Date.new(2015, 1, 1), Date.new(2017, 1, 1))

      [ brand_new, established, lapsed ].each { |organization| represent(organization, spring) }
    end

    it "splits the organizations represented at each training by status on its start date" do
      column = report.years.first.columns.first

      expect(column.event).to eq(spring)
      expect(column.new_count).to eq(1)
      expect(column.ongoing_count).to eq(1)
      expect(column.reinstated_count).to eq(1)
      expect(column.organization_count).to eq(3)
    end

    it "counts only organizations on active registrations" do
      cancelled_org = create(:organization, name: "Cancelled")
      represent(cancelled_org, spring, status: "cancelled")

      expect(report.years.first.columns.first.organization_count).to eq(3)
    end

    it "reads each organization as of the training it attended, not as of today" do
      # By the fall training the brand-new org has been facilitating since spring.
      represent(brand_new, fall)

      fall_column = report.columns.find { |column| column.event == fall }

      expect(fall_column.ongoing_count).to eq(1)
      expect(fall_column.new_count).to eq(0)
    end
  end

  describe "adding them up" do
    let(:repeat_org) { create(:organization, name: "Repeat") }
    let(:one_off) { create(:organization, name: "One Off") }

    before do
      facilitator_since(repeat_org, spring.start_date)
      facilitator_since(one_off, Date.new(2019, 5, 1))
      represent(repeat_org, spring)
      represent(repeat_org, fall)
      represent(one_off, fall)
    end

    it "sums the rows as organization-trainings, counting a repeat attender twice" do
      expect(report.organization_count).to eq(3)
      expect(report.new_count).to eq(1)     # Repeat, at spring
      expect(report.ongoing_count).to eq(2) # Repeat at fall, One Off at fall
    end

    it "counts each organization once for the period, at its earliest training" do
      expect(report.distinct_organization_count).to eq(2)
      expect(report.distinct_new_count).to eq(1)     # Repeat, as it was in spring
      expect(report.distinct_ongoing_count).to eq(1) # One Off
      expect(report).to be_repeat_organizations
    end
  end

  describe "grouping" do
    let(:last_year) { training("Prior Training", Date.new(2025, 6, 1)) }
    let(:report) { described_class.new([ spring, fall, last_year ].map(&:decorate)) }

    before do
      organization = create(:organization)
      facilitator_since(organization, Date.new(2019, 5, 1))
      [ spring, fall, last_year ].each { |event| represent(organization, event) }
    end

    it "groups columns by calendar year, newest first, chronological within a year" do
      expect(report.years.map(&:year)).to eq([ 2026, 2025 ])
      expect(report.years.first.columns.map(&:event)).to eq([ spring, fall ])
    end

    it "totals each year separately" do
      expect(report.years.first.organization_count).to eq(2)
      expect(report.years.last.organization_count).to eq(1)
    end

    it "counts the repeat organization once per year in the distinct view" do
      expect(report.years.first.distinct_organization_count).to eq(1)
      expect(report.distinct_organization_count).to eq(1)
    end
  end

  it "is empty without trainings" do
    empty = described_class.new([])

    expect(empty).not_to be_any
    expect(empty.organization_count).to eq(0)
    expect(empty.distinct_status_counts).to eq(new: 0, ongoing: 0, reinstated: 0)
  end

  it "loads the organizations and their affiliations in a fixed number of queries" do
    6.times do |index|
      organization = create(:organization, name: "Org #{index}")
      facilitator_since(organization, Date.new(2019, 5, 1))
      represent(organization, spring)
    end

    subject_report = report # build the events before measuring

    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { subject_report.columns }

    expect(queries).to be <= 3
  end
end
