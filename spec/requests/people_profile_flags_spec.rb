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
    profile_show_sectors: ">Sectors</h2>",
    profile_show_bio: ">Bio</h2>"
  }.each do |flag, marker|
    describe "##{flag}" do
      context "when false" do
        before { person.update!(flag => false) }

        it "hides content from other signed-in users" do
          sign_in create(:user)
          get person_path(person)
          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include(marker)
        end

        it "reveals content with the admin-or-owner wash on own profile" do
          sign_in owner_user
          get person_path(person)
          expect(washed?("admin-or-owner", marker)).to be(true)
        end

        it "reveals content with the admin-or-owner wash when admin views profile" do
          sign_in admin
          get person_path(person)
          expect(washed?("admin-or-owner", marker)).to be(true)
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
    before { create(:professional_license, person: person, kind: "LCSW", number: "11223") }

    context "when false" do
      before { person.update!(profile_show_credentials: false) }

      it "reveals the license credentials with the admin-or-owner wash on own profile" do
        sign_in owner_user
        get person_path(person)
        expect(washed?("admin-or-owner", "LCSW")).to be(true)
      end

      it "reveals the license credentials with the admin-or-owner wash when admin views profile" do
        sign_in admin
        get person_path(person)
        expect(washed?("admin-or-owner", "LCSW")).to be(true)
      end

      it "hides the license credentials from other users" do
        sign_in create(:user)
        get person_path(person)
        expect(response.body).not_to include("LCSW")
      end
    end

    context "when true" do
      before { person.update!(profile_show_credentials: true) }

      it "shows the license type as a suffix on own profile" do
        sign_in owner_user
        get person_path(person)
        expect(response.body).to include("LCSW")
      end

      it "shows the license type when admin views profile" do
        sign_in admin
        get person_path(person)
        expect(response.body).to include("LCSW")
      end
    end
  end

  describe "#profile_show_social_media" do
    context "when false" do
      before { person.update!(profile_show_social_media: false) }

      it "reveals social media with the admin-or-owner wash on own profile" do
        sign_in owner_user
        get person_path(person)
        expect(washed?("admin-or-owner", "fa-linkedin-in")).to be(true)
      end

      it "reveals social media with the admin-or-owner wash when admin views profile" do
        sign_in admin
        get person_path(person)
        expect(washed?("admin-or-owner", "fa-linkedin-in")).to be(true)
      end

      it "hides social media from other users" do
        sign_in create(:user)
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

      it "reveals email with the admin-or-owner wash on own profile" do
        sign_in owner_user
        get person_path(person)
        expect(washed?("admin-or-owner", email)).to be(true)
      end

      it "reveals email with the admin-or-owner wash when admin views profile" do
        sign_in admin
        get person_path(person)
        expect(washed?("admin-or-owner", email)).to be(true)
      end

      it "hides email from other users" do
        sign_in create(:user)
        get person_path(person)
        expect(response.body).not_to include(email)
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

    context "with a pending email change" do
      before do
        person.update!(profile_show_email: true)
        person.user.update_columns(unconfirmed_email: "aisha.new@example.com")
      end

      it "shows the pending address inline on own profile, not just in the hover title" do
        sign_in owner_user
        get person_path(person)
        expect(response.body).to include("Email change to <strong class=\"font-semibold\">aisha.new@example.com</strong> pending")
      end

      it "shows the pending address inline when admin views profile" do
        sign_in admin
        get person_path(person)
        expect(response.body).to include("Email change to <strong class=\"font-semibold\">aisha.new@example.com</strong> pending")
      end

      it "hides the pending change from other viewers" do
        sign_in create(:user)
        get person_path(person)
        expect(response.body).not_to include("aisha.new@example.com")
      end
    end
  end

  def washed?(marker_class, content)
    Nokogiri::HTML(response.body).css(".#{marker_class}").any? { |el| el.inner_html.include?(content) }
  end

  def section_heading(title)
    Nokogiri::HTML(response.body).css("h3").find { |h3| h3.text.strip == title }
  end

  def section_titles
    Nokogiri::HTML(response.body).css("h3").map { |h3| h3.text.strip }
  end

  def nearest_wash(title)
    section_heading(title)&.ancestors&.find { |node| node["class"].to_s.split.include?(DomainTheme.bg_class_for(:admin_or_owner, intensity: 100)) }
  end

  # Published-content sections stay visible to the owner and admins under a wash when turned off
  {
    profile_show_workshops: "Workshops authored",
    profile_show_workshop_variations: "Workshop variations authored",
    profile_show_stories: "Stories authored/featured",
    profile_show_resources: "Resources authored",
    profile_show_events_registered: "Events attended"
  }.each do |flag, title|
    badge = "Hidden from profile"

    describe "##{flag}" do
      context "when false" do
        before { person.update!(flag => false) }

        it "shows the section with the admin-or-owner wash on own profile" do
          sign_in owner_user
          get person_path(person)
          expect(nearest_wash(title)["class"]).to include("admin-or-owner")
          expect(nearest_wash(title).text).to include(badge)
        end

        it "shows the section with the admin-or-owner wash when admin views profile" do
          sign_in admin
          get person_path(person)
          expect(nearest_wash(title)["class"]).to include("admin-or-owner")
          expect(nearest_wash(title).text).to include(badge)
        end

        it "hides the section from other users" do
          sign_in create(:user)
          get person_path(person)
          expect(response).to have_http_status(:ok)
          expect(section_titles).not_to include(title)
        end
      end

      context "when true" do
        before { person.update!(flag => true) }

        it "shows the section without a badge on own profile" do
          sign_in owner_user
          get person_path(person)
          expect(section_heading(title).parent.text).not_to include(badge)
        end

        it "shows the section without a wash when admin views profile" do
          sign_in admin
          get person_path(person)
          expect(section_titles).to include(title)
          expect(nearest_wash(title)).to be_nil
        end

        it "shows the section to other users" do
          sign_in create(:user)
          get person_path(person)
          expect(response).to have_http_status(:ok)
          expect(section_titles).to include(title)
        end
      end
    end
  end

  describe "with every published-content section turned off" do
    before do
      person.update!(profile_show_workshops: false, profile_show_workshop_variations: false,
                     profile_show_stories: false, profile_show_resources: false)
    end

    it "washes the whole card once instead of each section" do
      sign_in admin
      get person_path(person)
      card = nearest_wash("Workshops authored")
      expect(card.text).to include("Published content")
      expect(card.text.scan("Hidden from profile").size).to eq(1)
    end
  end

  describe "submitted content" do
    submitted_titles = [ "Workshop ideas submitted", "Workshop variation ideas submitted",
                         "Story ideas submitted", "Workshop logs submitted" ]

    it "always shows under the admin-or-owner wash on own profile" do
      sign_in owner_user
      get person_path(person)
      submitted_titles.each { |title| expect(nearest_wash(title).text).to include("Only visible to you and admins") }
    end

    it "always shows under the admin-or-owner wash when admin views profile" do
      sign_in admin
      get person_path(person)
      submitted_titles.each { |title| expect(nearest_wash(title).text).to include("Only visible to this person and admins") }
    end

    it "never shows to other users" do
      sign_in create(:user)
      get person_path(person)
      expect(response).to have_http_status(:ok)
      expect(section_titles & submitted_titles).to be_empty
    end
  end
end
