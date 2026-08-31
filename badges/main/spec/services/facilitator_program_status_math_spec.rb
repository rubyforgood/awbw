require "rails_helper"

# How several people's facilitator affiliations add up to ONE verdict for the
# organization — at an anchor date (New / Ongoing / Reinstated) and right now
# (Active / Formerly active / Never active). ADR-0003 D3–D5.
#
# The single-affiliation boundary cases live in facilitator_program_status_spec.rb;
# this file is about the arithmetic across people, across anchors, and the
# relationship between the two questions.
RSpec.describe "facilitator affiliation math" do
  let(:organization) { create(:organization) }

  def facilitator(start_date:, end_date: nil, title: "Facilitator")
    create(:affiliation, organization: organization, person: create(:person),
                         title: title, start_date: start_date, end_date: end_date)
  end

  def status_on(date)
    organization.reload.facilitator_status_on(date)
  end

  def bucket
    organization.reload.decorate.organization_status_bucket
  end

  describe "several people at one anchor" do
    let(:anchor) { Date.new(2026, 6, 15) }

    it "is :ongoing when any one person is still facilitating, even if others have left" do
      facilitator(start_date: Date.new(2015, 1, 1), end_date: Date.new(2018, 1, 1))
      facilitator(start_date: Date.new(2019, 1, 1), end_date: Date.new(2020, 1, 1))
      facilitator(start_date: Date.new(2021, 1, 1))

      expect(status_on(anchor)).to eq(:ongoing)
    end

    it "is :reinstated only when EVERY earlier person has ended" do
      facilitator(start_date: Date.new(2015, 1, 1), end_date: Date.new(2018, 1, 1))
      facilitator(start_date: Date.new(2019, 1, 1), end_date: Date.new(2020, 1, 1))

      expect(status_on(anchor)).to eq(:reinstated)
    end

    it "is :new when every person starts on or after the anchor" do
      facilitator(start_date: anchor)
      facilitator(start_date: anchor)
      facilitator(start_date: anchor + 1.day)

      expect(status_on(anchor)).to eq(:new)
    end

    it "does not let people arriving at the training rescue a lapsed program" do
      facilitator(start_date: Date.new(2015, 1, 1), end_date: Date.new(2018, 1, 1))
      facilitator(start_date: anchor)
      facilitator(start_date: anchor)

      expect(status_on(anchor)).to eq(:reinstated)
    end

    it "counts only facilitators — a roomful of other titles is still :new" do
      facilitator(start_date: Date.new(2010, 1, 1), title: "Volunteer")
      facilitator(start_date: Date.new(2011, 1, 1), title: "Counselor")
      facilitator(start_date: Date.new(2012, 1, 1), title: "Lead Facilitator")

      expect(status_on(anchor)).to eq(:new)
    end
  end

  describe "the same organization read at different anchors" do
    it "reads :new on Jan 1 and :ongoing on Dec 31 when the program starts mid-year" do
      facilitator(start_date: Date.new(2026, 5, 4))

      expect(status_on(Date.new(2026, 1, 1))).to eq(:new)
      expect(status_on(Date.new(2026, 12, 31))).to eq(:ongoing)
    end

    it "reads :ongoing on Jan 1 and :reinstated on Dec 31 when the program lapses mid-year" do
      facilitator(start_date: Date.new(2022, 3, 1), end_date: Date.new(2026, 5, 4))

      expect(status_on(Date.new(2026, 1, 1))).to eq(:ongoing)
      expect(status_on(Date.new(2026, 12, 31))).to eq(:reinstated)
    end

    it "walks new → ongoing → reinstated → ongoing across a lapse and a return" do
      facilitator(start_date: Date.new(2020, 2, 1), end_date: Date.new(2022, 8, 1))
      facilitator(start_date: Date.new(2025, 9, 1))

      expect(status_on(Date.new(2019, 1, 1))).to eq(:new)
      expect(status_on(Date.new(2021, 1, 1))).to eq(:ongoing)
      expect(status_on(Date.new(2024, 1, 1))).to eq(:reinstated)
      expect(status_on(Date.new(2026, 1, 1))).to eq(:ongoing)
    end

    it "still reports what was true then after the program later ends" do
      affiliation = facilitator(start_date: Date.new(2020, 1, 1))
      expect(status_on(Date.new(2023, 1, 1))).to eq(:ongoing)

      affiliation.update!(end_date: Date.new(2024, 6, 1))

      expect(status_on(Date.new(2023, 1, 1))).to eq(:ongoing)
      expect(status_on(Date.new(2026, 1, 1))).to eq(:reinstated)
    end
  end

  describe "now (Active / Formerly active / Never active)" do
    it "is :never_active with no facilitator affiliation, whatever else the org has" do
      facilitator(start_date: 5.years.ago.to_date, title: "Volunteer")

      expect(bucket).to eq(:never_active)
    end

    it "is :active while any one person is still facilitating" do
      facilitator(start_date: 5.years.ago.to_date, end_date: 3.years.ago.to_date)
      facilitator(start_date: 2.years.ago.to_date)

      expect(bucket).to eq(:active)
    end

    it "is :formerly_active once every facilitator has ended — a subset of not-active" do
      facilitator(start_date: 5.years.ago.to_date, end_date: 3.years.ago.to_date)
      facilitator(start_date: 2.years.ago.to_date, end_date: 1.year.ago.to_date)

      expect(bucket).to eq(:formerly_active)
      expect(organization.reload.affiliations.facilitators.active).to be_empty
    end

    it "is :formerly_active when the flag ends a row the dates still call active" do
      affiliation = facilitator(start_date: 2.years.ago.to_date)
      expect(bucket).to eq(:active)

      affiliation.inactive_supplied = true
      affiliation.update!(inactive: true)

      expect(bucket).to eq(:formerly_active)
    end

    it "agrees with the SQL scope the index filter uses" do
      facilitator(start_date: 5.years.ago.to_date, end_date: 3.years.ago.to_date)

      expect(bucket).to eq(:formerly_active)
      expect(Organization.program_status(:formerly_active)).to include(organization)
      expect(Organization.program_status(:active)).not_to include(organization)
    end
  end

  describe "the two questions are independent" do
    it "reads Ongoing at a past training while reading Formerly active today" do
      facilitator(start_date: 4.years.ago.to_date, end_date: 1.year.ago.to_date)

      expect(status_on(2.years.ago.to_date)).to eq(:ongoing)
      expect(bucket).to eq(:formerly_active)
    end

    it "reads New at a past date while reading Active today" do
      facilitator(start_date: 1.year.ago.to_date)

      expect(status_on(3.years.ago.to_date)).to eq(:new)
      expect(bucket).to eq(:active)
    end
  end

  describe "reconciliation does not move an anchored verdict" do
    # Ending the day before the training (ADR-0003 D6) puts the row outside the
    # training's own anchor, so the org reads Reinstated there rather than Ongoing.
    # The years before it are still intact — every earlier anchor is unchanged.
    it "leaves every earlier anchor intact when a no-show's older affiliation is ended" do
      person = create(:person)
      event = create(:event, :ended, facilitator_training: true)
      anchor = event.start_date.to_date
      older = create(:affiliation, organization: organization, person: person,
                                   title: "Facilitator", start_date: 3.years.ago.to_date)
      registration = create(:event_registration, event: event, registrant: person, status: "no_show")
      create(:event_registration_organization, event_registration: registration, organization: organization)

      expect(status_on(anchor)).to eq(:ongoing)

      AffiliationServices::ReconcilePerson.new(
        person: person, organization: organization, event: event,
        registration: registration, include_unowned: true
      ).perform(:deactivate, affiliation: older)

      expect(status_on(anchor)).to eq(:reinstated)
      expect(status_on(anchor - 1.year)).to eq(:ongoing)
      expect(status_on(anchor + 1.year)).to eq(:reinstated)
      expect(bucket).to eq(:formerly_active)
    end

    it "leaves the verdict alone when the row the training minted is deleted" do
      person = create(:person)
      event = create(:event, :ended, facilitator_training: true)
      anchor = event.start_date.to_date
      registration = create(:event_registration, event: event, registrant: person, status: "no_show")
      create(:event_registration_organization, event_registration: registration, organization: organization)
      minted = create(:affiliation, organization: organization, person: person, title: "Facilitator",
                                    start_date: anchor, event_registration: registration)

      expect(status_on(anchor)).to eq(:new)

      AffiliationServices::ReconcilePerson.new(
        person: person, organization: organization, event: event,
        registration: registration, include_unowned: true
      ).perform(:delete, affiliation: minted)

      expect(status_on(anchor)).to eq(:new)
      expect(Affiliation.exists?(minted.id)).to be(false)
      expect(bucket).to eq(:never_active)
    end

    # Deactivating (rather than deleting) the row the training minted clamps its end
    # to its own start, leaving a zero-length row. Both questions must read that as
    # no facilitation, or the org edit form shows "Formerly active" beside a red
    # no-show chip (ADR-0001 D8a).
    it "leaves a deactivated no-show reading New and Never active, with no facilitator period" do
      person = create(:person)
      event = create(:event, :ended, facilitator_training: true)
      anchor = event.start_date.to_date
      registration = create(:event_registration, event: event, registrant: person, status: "no_show")
      create(:event_registration_organization, event_registration: registration, organization: organization)
      minted = create(:affiliation, organization: organization, person: person, title: "Facilitator",
                                    start_date: anchor, event_registration: registration)

      AffiliationServices::ReconcilePerson.new(
        person: person, organization: organization, event: event,
        registration: registration, include_unowned: true
      ).perform(:deactivate, affiliation: minted)

      expect(minted.reload.end_date).to eq(minted.start_date)
      expect(status_on(anchor)).to eq(:new)
      expect(status_on(anchor + 1.year)).to eq(:new)
      expect(bucket).to eq(:never_active)
      expect(organization.reload.decorate.program_since_display).to eq("")
      expect(Organization.program_status(:never_active)).to include(organization)
    end
  end
end
