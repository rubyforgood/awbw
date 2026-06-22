require "rails_helper"

RSpec.describe "Person profile flag visibility", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  before do
    person.update!(
      pronouns: "they/them",
      bio: "A passionate facilitator",
      linked_in_url: "https://linkedin.com/in/test"
    )
    owner_user.update!(phone: "555-123-4567")
    create(:affiliation, person: person, title: "Facilitator", start_date: Date.new(2020, 1, 1))
  end

  # Flags whose content is visible to any viewer with show access
  {
    profile_show_pronouns: "they/them",
    profile_show_member_since: "Facilitator since",
    profile_show_phone: "555-123-4567",
    profile_show_affiliations: "Affiliations",
    profile_show_sectors: "mb-3\">Sectors</h2>",
    profile_show_bio: "mb-3\">Bio</h2>",
    profile_show_workshops: "mb-3\">Workshops authored</h2>",
    profile_show_workshop_variations: "Workshop variations authored",
    profile_show_stories: "Stories authored/featured",
    profile_show_events_registered: "Participation history"
  }.each do |flag, marker|
    describe "##{flag}" do
      context "when false" do
        before { person.update!(flag => false) }

        it "hides content on own profile" do
          sign_in owner_user
          get person_path(person)
          expect(response.body).not_to include(marker)
        end

        it "hides content when admin views profile" do
          sign_in admin
          get person_path(person)
          expect(response.body).not_to include(marker)
        end
      end

      context "when true" do
        before { person.update!(flag => true) }

        it "shows content on own profile" do
          sign_in owner_user
          get person_path(person)
          expect(response.body).to include(marker)
        end

        it "shows content when admin views profile" do
          sign_in admin
          get person_path(person)
          expect(response.body).to include(marker)
        end
      end
    end
  end

  describe "#profile_show_credentials" do
    before { person.update!(credentials: "LCSW") }

    context "when false" do
      before { person.update!(profile_show_credentials: false) }

      it "hides credentials on own profile" do
        sign_in owner_user
        get person_path(person)
        expect(response.body).not_to include("LCSW")
      end
    end

    context "when true" do
      before { person.update!(profile_show_credentials: true) }

      it "shows credentials as a suffix on own profile" do
        sign_in owner_user
        get person_path(person)
        expect(response.body).to include("LCSW")
      end

      it "shows credentials when admin views profile" do
        sign_in admin
        get person_path(person)
        expect(response.body).to include("LCSW")
      end
    end
  end

  describe "#profile_show_social_media" do
    context "when false" do
      before { person.update!(profile_show_social_media: false) }

      it "hides social media on own profile" do
        sign_in owner_user
        get person_path(person)
        expect(response.body).not_to include("fa-linkedin-in")
      end
    end

    context "when true" do
      before { person.update!(profile_show_social_media: true) }

      it "shows social media on own profile" do
        sign_in owner_user
        get person_path(person)
        expect(response.body).to include("fa-linkedin-in")
      end

      it "shows social media when admin views profile" do
        sign_in admin
        get person_path(person)
        expect(response.body).to include("fa-linkedin-in")
      end
    end
  end

  describe "#profile_show_email" do
    let(:email) { person.user.email }

    context "when false" do
      before { person.update!(profile_show_email: false) }

      it "hides email on own profile" do
        sign_in owner_user
        get person_path(person)
        expect(response.body).not_to include(email)
      end

      it "shows email with admin-only styling when admin views profile" do
        sign_in admin
        get person_path(person)
        expect(response.body).to include(email)
        expect(response.body).to include("admin-only bg-blue-100")
      end
    end

    context "when true" do
      before { person.update!(profile_show_email: true) }

      it "shows email on own profile" do
        sign_in owner_user
        get person_path(person)
        expect(response.body).to include(email)
      end

      it "shows email when admin views profile" do
        sign_in admin
        get person_path(person)
        expect(response.body).to include(email)
      end
    end
  end

  # Flags inside the "Submitted content" section (gated by show? policy)
  {
    profile_show_workshop_ideas: "Workshop ideas submitted",
    profile_show_workshop_variation_ideas: "Workshop variation ideas submitted",
    profile_show_story_ideas: "Story ideas submitted",
    profile_show_workshop_logs: "Workshop logs submitted"
  }.each do |flag, marker|
    describe "##{flag}" do
      context "when false" do
        before { person.update!(flag => false) }

        it "hides content on own profile" do
          sign_in owner_user
          get person_path(person)
          expect(response.body).not_to include(marker)
        end
      end

      context "when true" do
        before { person.update!(flag => true) }

        it "shows content on own profile" do
          sign_in owner_user
          get person_path(person)
          expect(response.body).to include(marker)
        end

        it "shows content when admin views profile" do
          sign_in admin
          get person_path(person)
          expect(response.body).to include(marker)
        end
      end
    end
  end
end
