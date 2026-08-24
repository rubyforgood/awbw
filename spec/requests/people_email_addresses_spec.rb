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

      get email_addresses_people_path(contact_info: "Alice")

      expect(response).to have_http_status(:success)
      expect(response.body).to include("alice@example.com")
      expect(response.body).not_to include("bob@example.com")
    end

    it "falls back to the person's preferred email when the email column is blank" do
      create(:person, email: nil, user: create(:user, email: "dana@example.com"))
      create(:person, email: nil, email_2: "rio@example.com", user: nil)

      get email_addresses_people_path

      expect(response.body).to include("dana@example.com")
      expect(response.body).to include("rio@example.com")
    end

    it "shows the empty state when no people match" do
      get email_addresses_people_path(contact_info: "nobody-matches-this")

      expect(response.body).to include("No email addresses found.")
    end

    it "is admin-only" do
      sign_out admin
      sign_in create(:user)

      get email_addresses_people_path

      expect(response).to redirect_to(root_path)
    end
  end
end
