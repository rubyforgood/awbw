require "rails_helper"

RSpec.describe FacilitatorProgramStatus do
  let(:organization) { create(:organization) }
  let(:anchor) { Date.new(2026, 6, 15) }

  def facilitator(start_date:, end_date: nil, title: "Facilitator")
    create(:affiliation, organization: organization, person: create(:person),
                         title: title, start_date: start_date, end_date: end_date)
  end

  def status_on(date = anchor)
    organization.reload.facilitator_program_status(as_of: date)
  end

  describe "the verdict" do
    it "is :new without any facilitator affiliation before the anchor" do
      expect(status_on.status).to eq(:new)
    end

    it "is :new when the only facilitator affiliation starts ON the anchor" do
      # The affiliation the training itself mints — not prior history.
      facilitator(start_date: anchor)
      expect(status_on.status).to eq(:new)
    end

    it "is :ongoing when an earlier facilitator affiliation is still active" do
      facilitator(start_date: Date.new(2019, 3, 1))
      expect(status_on.status).to eq(:ongoing)
    end

    it "is :ongoing when an earlier affiliation ends exactly on the anchor" do
      facilitator(start_date: Date.new(2019, 3, 1), end_date: anchor)
      expect(status_on.status).to eq(:ongoing)
    end

    it "is :reinstated when every earlier facilitator affiliation has ended" do
      facilitator(start_date: Date.new(2015, 8, 1), end_date: Date.new(2018, 6, 1))
      expect(status_on.status).to eq(:reinstated)
    end

    it "ignores non-facilitator affiliations" do
      facilitator(start_date: Date.new(2010, 1, 1), title: "Volunteer")
      expect(status_on.status).to eq(:new)
    end
  end

  describe "the anchor" do
    it "reads as of the given date" do
      expect(status_on.as_of).to eq(anchor)
      expect(status_on).not_to be_year_anchored
    end

    it "falls back to the start of the current year when no date is given" do
      status = status_on(nil)

      expect(status.as_of).to eq(Date.current.beginning_of_year)
      expect(status).to be_year_anchored
    end
  end

  describe "#explanation" do
    it "names the anchor, the date the program went active, and the periods" do
      facilitator(start_date: Date.new(2019, 3, 1))

      explanation = status_on.explanation

      expect(explanation).to include("Ongoing as of Jun 15, 2026 (event start date).")
      expect(explanation).to include("Active facilitator affiliation since Mar 2019.")
      expect(explanation).to include("Facilitator periods: Mar 2019.")
    end

    it "names when a reinstated program last ran" do
      facilitator(start_date: Date.new(2015, 8, 1), end_date: Date.new(2018, 6, 1))

      explanation = status_on.explanation

      expect(explanation).to include("Reinstated as of Jun 15, 2026")
      expect(explanation).to include("Previously active from Aug 2015 through Jun 2018")
      expect(explanation).to include("Facilitator periods: Aug 2015 – Jun 2018.")
    end

    it "says there is no prior history for a new program" do
      expect(status_on.explanation).to include("New as of Jun 15, 2026", "No facilitator affiliation started before this date.")
    end

    it "says the year is the anchor when there is no event in view" do
      expect(status_on(nil).explanation).to include("no event in view")
    end

    # The most recent activation is what the hover reports, not the earliest.
    it "reports the latest of several overlapping active affiliations" do
      facilitator(start_date: Date.new(2019, 3, 1))
      facilitator(start_date: Date.new(2024, 9, 1))

      expect(status_on.active_since).to eq(Date.new(2024, 9, 1))
    end
  end

  # List pages classify many organizations at once, so this has to ride on the
  # preloaded association rather than querying per row.
  it "reads preloaded affiliations without querying" do
    facilitator(start_date: Date.new(2019, 3, 1))
    preloaded = Organization.where(id: organization.id).includes(:affiliations).first

    queries = 0
    counter = ->(*, payload) { queries += 1 if payload[:sql].to_s.include?("FROM `affiliations`") }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      expect(preloaded.facilitator_program_status(as_of: anchor).explanation).to be_present
    end

    expect(queries).to eq(0)
  end
end
