require "rails_helper"

RSpec.describe PersonDecorator do
  describe "#address_phones" do
    it "numbers address phones by position, leaving out ones already listed as phones" do
      person = create(:person)
      create(:address, addressable: person, phone: "(123) 123-1234")
      create(:address, addressable: person, phone: "123-332-1234")
      create(:contact_method, contactable: person, value: "123.123.1234")

      expect(person.reload.decorate.address_phones).to eq([ [ 2, "123-332-1234" ] ])
    end
  end

  describe "#work_address_phones" do
    it "pairs each linked work address phone with its organization, leaving out ones already listed" do
      person = create(:person)
      sunrise = create(:organization, name: "Sunrise Center")
      harbor = create(:organization, name: "Harbor House")
      create(:affiliation, person: person, organization: sunrise,
                           organization_address: create(:address, addressable: sunrise, phone: "123-123-1444"))
      create(:affiliation, person: person, organization: harbor,
                           organization_address: create(:address, addressable: harbor, phone: "123-123-1233"))
      create(:contact_method, contactable: person, value: "(123) 123-1233")

      expect(person.decorate.work_address_phones).to eq([ [ "Sunrise Center", "123-123-1444" ] ])
    end
  end

  describe "#work_address_affiliations" do
    it "lists active affiliations linked to an org address, once per address" do
      person = create(:person)
      organization = create(:organization)
      address = create(:address, addressable: organization)
      linked = create(:affiliation, person: person, organization: organization, organization_address: address)
      create(:affiliation, person: person, organization: organization, organization_address: address, title: "Director")
      create(:affiliation, person: person, organization: create(:organization), title: "Volunteer")
      create(:affiliation, person: person, organization: organization, organization_address: create(:address, addressable: organization),
                           title: "Counselor", start_date: 3.years.ago.to_date, end_date: 1.year.ago.to_date)

      expect(person.decorate.work_address_affiliations).to eq([ linked ])
    end
  end

  describe "#unlocked_membership_count" do
    let(:person) { create(:person) }

    before do
      create(:membership, person: person)
      create(:membership, :renewal_off, person: person,
        start_date: Date.current - 3.years, end_date: Date.current - 2.years,
        locked_at: Time.current)
    end

    it "counts only unlocked memberships" do
      expect(person.decorate.unlocked_membership_count).to eq(1)
      expect(person.decorate.multiple_unlocked_memberships?).to be(false)
    end

    it "counts correctly when the association is preloaded" do
      loaded_person = Person.includes(:memberships).find(person.id)

      expect(loaded_person.decorate.unlocked_membership_count).to eq(1)
      expect(loaded_person.decorate.multiple_unlocked_memberships?).to be(false)
    end
  end

  describe ".email_with_type" do
    it "abbreviates a work or personal email and leaves an unknown one bare" do
      expect(described_class.email_with_type("ada@example.com", "work")).to eq("ada@example.com (w)")
      expect(described_class.email_with_type("ada@example.com", "unknown")).to eq("ada@example.com")
    end
  end

  describe "#user_accounts" do
    let(:person) { create(:person) }

    it "lists every login on the person, most recently updated first" do
      older = person.user.tap { |user| user.update_columns(updated_at: 2.days.ago) }
      newer = create(:user, person: person, updated_at: 1.hour.ago)
      create(:user)

      expect(person.decorate.user_accounts).to eq([ newer, older ])
      expect(person.decorate.multiple_user_accounts?).to be(true)
    end

    it "suggests keeping the most recent login that can still sign in" do
      usable = person.user
      create(:user, person: person, confirmed_at: nil, updated_at: 1.minute.from_now)

      expect(person.decorate.suggested_user_account).to eq(usable)
    end

    it "does not flag a person with one login" do
      expect(person.decorate.multiple_user_accounts?).to be(false)
    end
  end

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

  describe "#profile_email" do
    it "prefers the login email" do
      person = create(:person, email: "record@example.com")

      expect(person.decorate.profile_email).to eq(person.user.email)
    end

    it "falls back to the record email" do
      person = create(:person, user: nil, email: "record@example.com", email_2: "secondary@example.com")

      expect(person.decorate.profile_email).to eq("record@example.com")
    end

    it "never returns the admin-only secondary email" do
      person = create(:person, user: nil, email: nil, email_2: "secondary@example.com")

      expect(person.decorate.profile_email).to be_nil
    end

    it "ignores the no-email placeholder" do
      person = create(:person, user: nil, email: PlaceholderEmail.first)

      expect(person.decorate.profile_email).to be_nil
    end
  end

  describe "#profile_email_login?" do
    it "is true when the profile email is the login email" do
      expect(create(:person).decorate.profile_email_login?).to be(true)
    end

    it "is false without a user account" do
      expect(create(:person, user: nil, email: "record@example.com").decorate.profile_email_login?).to be(false)
    end
  end

  describe "#profile_email_label" do
    it "marks the login email as the user account" do
      expect(create(:person).decorate.profile_email_label).to eq("primary · user account")
    end

    it "marks a record-only email as primary" do
      person = create(:person, user: nil, email: "record@example.com")

      expect(person.decorate.profile_email_label).to eq("primary")
    end
  end

  describe "#email_2_label" do
    it "adds the email type" do
      expect(build(:person, email_2_type: "personal").decorate.email_2_label).to eq("email2 · personal")
    end

    it "is just email2 without a type" do
      expect(build(:person, email_2_type: nil).decorate.email_2_label).to eq("email2")
    end
  end

  describe "#hidden_profile_pieces" do
    it "is empty when every piece is shared" do
      expect(create(:person, profile_show_email: true).decorate.hidden_profile_pieces).to be_empty
    end

    it "lists hidden pieces that have something to show" do
      person = create(:person, pronouns: "they/them", profile_show_email: true, profile_show_pronouns: false, profile_show_workshops: false)

      expect(person.decorate.hidden_profile_pieces).to eq(%i[profile_show_pronouns profile_show_workshops])
    end

    it "skips hidden pieces with nothing to show" do
      person = create(:person, pronouns: nil, bio: nil, profile_show_email: true, profile_show_pronouns: false, profile_show_bio: false)

      expect(person.decorate.hidden_profile_pieces).to be_empty
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
