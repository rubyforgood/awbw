require "rails_helper"

RSpec.describe PersonDecorator do
  describe "#news_subscriptions_path" do
    let(:person) { create(:person) }

    it "links to the subscriptions index filtered to this person and the News topic" do
      news = create(:topic_subscription_type, name: "News")

      path = person.decorate.news_subscriptions_path

      expect(path).to include("person_id=#{person.id}")
      expect(path).to include("topic_subscription_type_id=#{news.id}")
    end

    it "still filters by person when no News topic exists" do
      path = person.decorate.news_subscriptions_path

      expect(path).to include("person_id=#{person.id}")
    end
  end

  describe "#active_facilitator_organization_names" do
    let(:person) { create(:person) }

    it "returns sorted, unique org names for active facilitator affiliations" do
      beta = create(:organization, name: "Beta Org")
      alpha = create(:organization, name: "Alpha Org")
      create(:affiliation, person: person, organization: beta, title: "Facilitator")
      create(:affiliation, person: person, organization: alpha, title: "Facilitator")

      expect(person.decorate.active_facilitator_organization_names).to eq([ "Alpha Org", "Beta Org" ])
    end

    it "excludes non-facilitator affiliations" do
      org = create(:organization, name: "Board Org")
      create(:affiliation, person: person, organization: org, title: "Board Member")

      expect(person.decorate.active_facilitator_organization_names).to be_empty
    end

    it "excludes expired facilitator affiliations" do
      org = create(:organization, name: "Past Org")
      create(:affiliation, person: person, organization: org, title: "Facilitator", end_date: 1.day.ago)

      expect(person.decorate.active_facilitator_organization_names).to be_empty
    end
  end

  describe "#affiliated_since_date" do
    let(:person) { create(:person) }

    it "returns the earliest affiliation start date" do
      create(:affiliation, person: person, start_date: Date.new(2024, 5, 1))
      create(:affiliation, person: person, start_date: Date.new(2022, 3, 1))
      create(:affiliation, person: person, start_date: Date.new(2023, 8, 1))

      expect(person.decorate.affiliated_since_date).to eq(Date.new(2022, 3, 1))
    end

    it "ignores affiliations without a start date" do
      create(:affiliation, person: person, start_date: nil)
      create(:affiliation, person: person, start_date: Date.new(2021, 1, 1))

      expect(person.decorate.affiliated_since_date).to eq(Date.new(2021, 1, 1))
    end

    it "is nil when there are no affiliations with a start date" do
      create(:affiliation, person: person, start_date: nil)

      expect(person.decorate.affiliated_since_date).to be_nil
    end
  end

  describe "#facilitator_since_year" do
    let(:person) { create(:person) }

    it "returns the earliest facilitator affiliation year, ignoring other roles" do
      create(:affiliation, person: person, title: "Volunteer", start_date: Date.new(2015, 1, 1))
      create(:affiliation, person: person, title: "Facilitator", start_date: Date.new(2020, 6, 1))
      expect(person.decorate.facilitator_since_year).to eq(2020)
    end

    it "falls back to member_since for a facilitator affiliation with no start date" do
      person.update!(member_since: Date.new(2018, 3, 1))
      create(:affiliation, person: person, title: "Facilitator", start_date: nil)
      expect(person.decorate.facilitator_since_year).to eq(2018)
    end

    it "is nil when the person has never held a facilitator affiliation" do
      person.update!(member_since: Date.new(2018, 3, 1))
      create(:affiliation, person: person, title: "Counselor", start_date: Date.new(2015, 1, 1))
      expect(person.decorate.facilitator_since_year).to be_nil
    end

    it "is nil when the person has no affiliations at all" do
      person.update!(member_since: Date.new(2018, 3, 1))
      expect(person.decorate.facilitator_since_year).to be_nil
    end
  end

  describe "#facilitator_status_label" do
    let(:person) { create(:person) }

    it "is Inactive when the person has never been a facilitator" do
      create(:affiliation, person: person, title: "Volunteer", start_date: 1.year.ago)
      expect(person.decorate.facilitator_status_label).to eq("Inactive")
    end

    it "is Active with a current facilitator affiliation" do
      create(:affiliation, person: person, title: "Facilitator", start_date: 1.year.ago, end_date: nil)
      expect(person.decorate.facilitator_status_label).to eq("Active")
    end

    it "is Upcoming when a facilitator affiliation is scheduled but none is active" do
      create(:affiliation, person: person, title: "Facilitator", start_date: 1.month.from_now, end_date: nil)
      expect(person.decorate.facilitator_status_label).to eq("Upcoming")
    end

    it "is Inactive when every facilitator term has ended" do
      create(:affiliation, person: person, title: "Facilitator", start_date: 3.years.ago, end_date: 1.year.ago)
      expect(person.decorate.facilitator_status_label).to eq("Inactive")
    end
  end

  describe "#affiliated_since_note" do
    let(:person) { create(:person) }

    it "surfaces the affiliation start when it differs from the facilitator start" do
      create(:affiliation, person: person, title: "Board Member", start_date: Date.new(2015, 3, 1))
      create(:affiliation, person: person, title: "Facilitator", start_date: Date.new(2018, 8, 1))

      expect(person.decorate.affiliated_since_note).to eq("Affiliated since Mar 2015")
    end

    it "is nil when the affiliation and facilitator starts share a month and year" do
      create(:affiliation, person: person, title: "Facilitator", start_date: Date.new(2018, 8, 1))

      expect(person.decorate.affiliated_since_note).to be_nil
    end

    it "is nil when there is no affiliation start date" do
      create(:affiliation, person: person, start_date: nil)

      expect(person.decorate.affiliated_since_note).to be_nil
    end
  end

  describe "#full_name_with_display_name" do
    it "shows just the full name when that is how the person is displayed" do
      person = build(:person, first_name: "Mariana", last_name: "Lopez", display_name_preference: "full_name")

      expect(person.decorate.full_name_with_display_name).to eq("Mariana Lopez")
    end

    it "adds the display name in parens when it differs" do
      person = build(:person, first_name: "Mariana", last_name: "Lopez",
                              display_name_preference: "first_name_last_initial")

      expect(person.decorate.full_name_with_display_name).to eq("Mariana Lopez (Mariana L.)")
    end
  end
end
