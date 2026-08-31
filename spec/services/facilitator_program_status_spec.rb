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

    it "is :new for a same-day (start == end) facilitation dated to the anchor" do
      # A zero-length row is what a no-show / cancelled training leaves (ADR-0001
      # D8a); it represents no facilitation and is dropped, so a first-time org
      # still reads New.
      facilitator(start_date: anchor, end_date: anchor)
      expect(status_on.status).to eq(:new)
    end

    it "is :new for an affiliation that starts on the anchor with a later end date" do
      # Still the minted affiliation (starts on the event), just not open-ended.
      facilitator(start_date: anchor, end_date: anchor + 30)
      expect(status_on.status).to eq(:new)
    end

    it "is :new for a zero-length facilitation that ran before the anchor" do
      # A no-show at an earlier training leaves a same-day row (ADR-0001 D8a). It is
      # not prior facilitation, so it must not reinstate the org at a later date.
      facilitator(start_date: Date.new(2020, 1, 1), end_date: Date.new(2020, 1, 1))
      expect(status_on.status).to eq(:new)
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

  # Status is per-organization over ALL its facilitator affiliations (ADR-0001 D5),
  # so a freshly-minted affiliation never downgrades a program that other affiliations
  # already make Ongoing or Reinstated.
  describe "combining multiple facilitator affiliations" do
    it "is :ongoing when a prior active affiliation coexists with one minted at the anchor" do
      facilitator(start_date: Date.new(2019, 3, 1))                 # prior, still active
      facilitator(start_date: anchor)                              # minted at this training
      expect(status_on.status).to eq(:ongoing)
    end

    it "is :reinstated when only lapsed history coexists with one minted at the anchor" do
      facilitator(start_date: Date.new(2015, 1, 1), end_date: Date.new(2017, 1, 1))  # lapsed
      facilitator(start_date: anchor)                                                # minted
      expect(status_on.status).to eq(:reinstated)
    end

    it "is :ongoing when an active affiliation coexists with a lapsed one" do
      facilitator(start_date: Date.new(2015, 1, 1), end_date: Date.new(2017, 1, 1))  # lapsed
      facilitator(start_date: Date.new(2023, 1, 1))                                  # active
      expect(status_on.status).to eq(:ongoing)
    end

    it "is :new only when every facilitator affiliation is dated on/after the anchor" do
      facilitator(start_date: anchor)                     # minted, open-ended
      facilitator(start_date: anchor, end_date: anchor)   # minted, same-day
      facilitator(start_date: anchor + 5)                 # starts after the event
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

    # The anchor is the event's start date, never "today", so an org whose only
    # facilitator affiliation was minted at a training reads New at that training
    # whenever you look — on any day of a multi-day event, and years afterward.
    it "reads New at the training on every day of it and looking back" do
      org = create(:organization)
      training_start = Date.new(2026, 9, 10)
      create(:affiliation, person: create(:person), organization: org,
                           title: "Facilitator", start_date: training_start, end_date: nil)
      org.reload

      [ training_start, training_start + 1.day, training_start + 2.days ].each do |viewed_on|
        travel_to(viewed_on) do
          expect(org.facilitator_program_status(as_of: training_start).status).to eq(:new)
        end
      end

      travel_to(training_start + 3.years) do
        expect(org.facilitator_program_status(as_of: training_start).status).to eq(:new)
      end
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
