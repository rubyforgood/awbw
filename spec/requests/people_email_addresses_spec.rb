require "rails_helper"

RSpec.describe "People email addresses", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /people/email_addresses" do
    it "lists the filtered people's unique emails comma-separated" do
      create(:person, first_name: "Alice", last_name: "Wonderland",
                      email: "alice@example.com", user: nil)
      create(:person, first_name: "Bob", last_name: "Builder",
                      email: "bob@example.com", user: nil)

      get email_addresses_people_path(name_email: "Alice")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("alice@example.com")
      expect(response.body).not_to include("bob@example.com")
    end

    it "matches contact details like the people index" do
      person = create(:person, first_name: "Carol", last_name: "Phoner",
                              email: "carol@example.com", user: nil)
      create(:contact_method, contactable: person, value: "555-0142")

      get email_addresses_people_path(contact_info: "555-0142")

      expect(response.body).to include("carol@example.com")
    end

    it "narrows by where people work" do
      organization = create(:organization)
      create(:address, addressable: organization, city: "Reno", state: "NV")
      worker = create(:person, email: "reno@example.com", user: nil)
      create(:affiliation, person: worker, organization: organization)
      create(:person, email: "elsewhere@example.com", user: nil)

      get email_addresses_people_path(work_location: "city: reno")

      expect(response.body).to include("reno@example.com")
      expect(response.body).not_to include("elsewhere@example.com")
    end

    it "falls back to the person's preferred email when the email column is blank" do
      create(:person, email: nil, user: create(:user, email: "dana@example.com"))
      create(:person, email: nil, email_2: "rio@example.com", user: nil)

      get email_addresses_people_path

      expect(response.body).to include("dana@example.com")
      expect(response.body).to include("rio@example.com")
    end

    it "shows the empty state when no people match" do
      get email_addresses_people_path(name_email: "nobody-matches-this")

      expect(response.body).to include("No email addresses found.")
    end

    it "is admin-only" do
      sign_out admin
      sign_in create(:user)

      get email_addresses_people_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "Email addresses link on the filtered index frame" do
    it "carries the active filter into the Email addresses link" do
      get people_path(name_email: "Alice"), headers: { "Turbo-Frame" => "people_results" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(email_addresses_people_path(name_email: "Alice"))
    end
  end
end
