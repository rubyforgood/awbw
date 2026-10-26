require "rails_helper"

RSpec.describe "Person profile flag visibility", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let(:other_user) { create(:user) }

  before do
    person.update!(
      pronouns: "they/them",
      bio: "A passionate facilitator",
      linked_in_url: "https://linkedin.com/in/test"
    )
    owner_user.update!(phone: "555-123-4567")
    create(:affiliation, person: person, title: "Facilitator", start_date: Date.new(2020, 1, 1))
  end

  def hidden_card
    Capybara.string(response.body).all("#hidden_from_profile").first
  end

  # flag => [marker in its public spot, text inside the "Hidden from profile" card]
  {
    profile_show_pronouns: [ "(they/them)", "they/them" ],
    profile_show_member_since: [ "Facilitator since", "Facilitator since" ],
    profile_show_phone: [ "555-123-4567", "555-123-4567" ],
    profile_show_affiliations: [ "\">Affiliations</h2>", "Affiliations" ],
    profile_show_sectors: [ "\">Sectors</h2>", "Sectors" ],
    profile_show_bio: [ "\">Bio</h2>", "A passionate facilitator" ],
    profile_show_workshops: [ "\">Workshops authored</h3>", "Workshops authored" ],
    profile_show_workshop_variations: [ "Workshop variations authored", "Workshop variations authored" ],
    profile_show_stories: [ "Stories authored/featured", "Stories authored/featured" ],
    profile_show_resources: [ "\">Resources authored</h3>", "Resources authored" ],
    profile_show_events_registered: [ "Participation history", "Events attended" ]
  }.each do |flag, (public_marker, hidden_text)|
    describe "##{flag}" do
      context "when false" do
        before { person.update!(flag => false) }

        it "hides content from other signed-in users" do
          sign_in other_user
          get person_path(person)
          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include(public_marker)
          expect(hidden_card).to be_nil
        end

        it "shows content to the owner in the hidden-from-profile card" do
          sign_in owner_user
          get person_path(person)
          expect(hidden_card).to be_present
          expect(hidden_card.native.to_html).to include(hidden_text)
          expect(response.body).to include("Only visible to you and admins")
        end

        it "shows content to an admin in the hidden-from-profile card" do
          sign_in admin
          get person_path(person)
          expect(hidden_card.native.to_html).to include(hidden_text)
          expect(response.body).to include("Only visible to this person and admins")
        end
      end

      context "when true" do
        before { person.update!(flag => true) }

        it "shows content to other signed-in users" do
          sign_in other_user
          get person_path(person)
          expect(response.body).to include(public_marker)
        end

        it "shows content on own profile" do
          sign_in owner_user
          get person_path(person)
          expect(response.body).to include(public_marker)
        end

        it "shows content when admin views profile" do
          sign_in admin
          get person_path(person)
          expect(response.body).to include(public_marker)
        end
      end
    end
  end

  describe "#profile_show_credentials" do
    before { create(:professional_license, person: person, kind: "LCSW", number: "11223") }

    context "when false" do
      before { person.update!(profile_show_credentials: false) }

      it "hides the license credentials from other signed-in users" do
        sign_in other_user
        get person_path(person)
        expect(response.body).not_to include("LCSW")
      end

      it "shows the license credentials to the owner in the hidden-from-profile card" do
        sign_in owner_user
        get person_path(person)
        expect(hidden_card.native.to_html).to include("LCSW")
      end

      it "shows the license credentials to an admin in the hidden-from-profile card" do
        sign_in admin
        get person_path(person)
        expect(hidden_card.native.to_html).to include("LCSW")
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

      it "hides social media from other signed-in users" do
        sign_in other_user
        get person_path(person)
        expect(response.body).not_to include("fa-linkedin-in")
      end

      it "shows social media to the owner in the hidden-from-profile card" do
        sign_in owner_user
        get person_path(person)
        expect(hidden_card.native.to_html).to include("fa-linkedin-in")
      end

      it "shows social media to an admin in the hidden-from-profile card" do
        sign_in admin
        get person_path(person)
        expect(hidden_card.native.to_html).to include("fa-linkedin-in")
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

      it "hides email from other signed-in users" do
        sign_in other_user
        get person_path(person)
        expect(response.body).not_to include(email)
      end

      it "shows email to the owner in the hidden-from-profile card" do
        sign_in owner_user
        get person_path(person)
        expect(hidden_card.native.to_html).to include(email)
      end

      it "shows email to an admin in the hidden-from-profile card" do
        sign_in admin
        get person_path(person)
        expect(hidden_card.native.to_html).to include(email)
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

  def section_heading(title)
    Nokogiri::HTML(response.body).css("h3").find { |h3| h3.text.strip == title }
  end

  def section_titles
    Nokogiri::HTML(response.body).css("h3").map { |h3| h3.text.strip }
  end

  def nearest_wash(title)
    section_heading(title)&.ancestors&.find { |node| node["class"].to_s.split.include?(DomainTheme.bg_class_for(:admin_or_owner, intensity: 100)) }
  end

  describe "hidden-from-profile card" do
    before { person.update!(profile_show_bio: false) }

    it "takes the admin-or-owner wash" do
      sign_in owner_user
      get person_path(person)
      expect(hidden_card[:class]).to include("admin-or-owner", DomainTheme.bg_class_for(:admin_or_owner, intensity: 100))
      expect(hidden_card.text).to include("Hidden from profile")
    end

    it "starts open and can be collapsed" do
      sign_in owner_user
      get person_path(person)
      expect(hidden_card["data-expandable-card-expanded-value"]).to eq("true")
      expect(hidden_card.find("[data-expandable-card-target='body']", visible: :all)[:class]).not_to include("hidden")
    end

    it "is absent when nothing is hidden" do
      person.update!(profile_show_bio: true, profile_show_pronouns: true, profile_show_email: true, profile_show_phone: true, profile_show_social_media: true)
      sign_in owner_user
      get person_path(person)
      expect(hidden_card).to be_nil
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
  describe "lazy section requests" do
    before { person.update!(profile_show_workshops: false) }

    def get_workshops_section
      get person_path(person, section: "workshops"), headers: { "Turbo-Frame" => "person_workshops_section" }
    end

    it "denies a hidden section to other signed-in users" do
      sign_in other_user
      get_workshops_section
      expect(response).to redirect_to(root_path)
    end

    it "serves a hidden section to the owner" do
      sign_in owner_user
      get_workshops_section
      expect(response).to be_successful
    end
  end
end
