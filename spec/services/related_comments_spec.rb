require "rails_helper"

RSpec.describe RelatedComments do
  def bodies_for(commentable)
    described_class.new(commentable).comments.map(&:body)
  end

  describe "EventRegistration" do
    it "gathers the registration, registrant, their user, and active orgs" do
      registrant = create(:person)
      reg = create(:event_registration, registrant:)
      org = create(:organization)
      create(:affiliation, person: registrant, organization: org)
      inactive_org = create(:organization)
      create(:affiliation, person: registrant, organization: inactive_org, inactive: true)

      create(:comment, commentable: reg, body: "reg")
      create(:comment, commentable: registrant, body: "person")
      create(:comment, commentable: registrant.user, body: "user")
      create(:comment, commentable: org, body: "org")
      create(:comment, commentable: inactive_org, body: "inactive-org")

      expect(bodies_for(reg)).to contain_exactly("reg", "person", "user", "org")
    end
  end

  describe "Person" do
    it "gathers the person, their user, and active orgs" do
      person = create(:person)
      org = create(:organization)
      create(:affiliation, person:, organization: org)

      create(:comment, commentable: person, body: "person")
      create(:comment, commentable: person.user, body: "user")
      create(:comment, commentable: org, body: "org")

      expect(bodies_for(person)).to contain_exactly("person", "user", "org")
    end
  end

  describe "Organization" do
    it "gathers the org and people with an active affiliation" do
      org = create(:organization)
      active_person = create(:person)
      create(:affiliation, person: active_person, organization: org)
      inactive_person = create(:person)
      create(:affiliation, person: inactive_person, organization: org, inactive: true)

      create(:comment, commentable: org, body: "org")
      create(:comment, commentable: active_person, body: "active")
      create(:comment, commentable: inactive_person, body: "inactive")

      expect(bodies_for(org)).to contain_exactly("org", "active")
    end
  end

  describe "User" do
    it "gathers the user, its person, and the person's active orgs" do
      person = create(:person)
      org = create(:organization)
      create(:affiliation, person:, organization: org)

      create(:comment, commentable: person.user, body: "user")
      create(:comment, commentable: person, body: "person")
      create(:comment, commentable: org, body: "org")

      expect(bodies_for(person.user)).to contain_exactly("user", "person", "org")
    end
  end

  describe "Workshop" do
    it "gathers the workshop and its creator" do
      creator = create(:user)
      workshop = create(:workshop, created_by: creator)

      create(:comment, commentable: workshop, body: "workshop")
      create(:comment, commentable: creator, body: "creator")

      expect(bodies_for(workshop)).to include("workshop", "creator")
    end
  end
end
