require "rails_helper"

RSpec.describe "People index share toggles", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:viewer) { create(:user, :with_person) }
  let(:turbo_headers) { { "Turbo-Frame" => "people_results", "Accept" => "text/html" } }
  let(:person) { create(:person, first_name: "Shared", linked_in_url: "https://linkedin.com/in/shared-person") }
  let(:organization) { create(:organization, name: "Visible Org") }
  let(:age_type) { create(:category_type, :published, name: "AgeRange") }

  before do
    create(:affiliation, person: person, organization: organization, start_date: Date.new(2019, 3, 1))
    person.sectorable_items.create!(sector: create(:sector, :published, name: "Zoo sector"), is_primary: true)
    person.categorizable_items.create!(category: create(:category, :published, category_type: age_type, name: "Teens (13-17)"), is_primary: true)
  end

  {
    profile_show_member_since: "2019",
    profile_show_sectors: "Zoo sector",
    profile_show_age_ranges: "Teens (13-17)",
    profile_show_affiliations: "Visible Org",
    profile_show_social_media: "linkedin.com/in/shared-person"
  }.each do |flag, marker|
    describe "##{flag}" do
      it "shows the column content to a signed-in user when on" do
        sign_in viewer
        get people_path, headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(marker)
      end

      it "hides the column content from a signed-in user when off" do
        person.update!(flag => false)
        sign_in viewer
        get people_path, headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Shared")
        expect(response.body).not_to include(marker)
      end

      it "still shows the content to an admin, marked hidden from public, when off" do
        person.update!(flag => false)
        sign_in admin
        get people_path, headers: turbo_headers

        expect(response.body).to include(marker)
        expect(response.body).to include("Hidden from public")
      end

      it "still shows the person their own content, marked hidden from public, when off" do
        person.update!(flag => false)
        sign_in person.user
        get people_path, headers: turbo_headers

        expect(response.body).to include(marker)
        expect(response.body).to include("Hidden from public")
      end
    end
  end

  describe "email" do
    let(:person) { create(:person, first_name: "Shared", user: nil, email: nil, email_2: "secondary@example.com") }

    it "never shows the admin-only secondary email to a signed-in user" do
      sign_in viewer
      get people_path, headers: turbo_headers

      expect(response.body).to include("Shared")
      expect(response.body).not_to include("secondary@example.com")
    end

    it "shows the secondary email to an admin" do
      sign_in admin
      get people_path, headers: turbo_headers

      expect(response.body).to include("secondary@example.com")
    end
  end
end
