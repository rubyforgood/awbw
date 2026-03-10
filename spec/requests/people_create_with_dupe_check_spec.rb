require "rails_helper"

RSpec.describe "POST /people with duplicate check", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:existing_person) { create(:person, first_name: "Jane", last_name: "Doe", email: "jane.doe@example.com") }

  before { sign_in admin }

  context "when duplicates are found" do
    it "renders the new form with duplicate warning instead of redirecting" do
      post people_path, params: {
        person: { first_name: "Jane", last_name: "Doe", email: "new@testmail.org", created_by_id: admin.id, updated_by_id: admin.id }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Possible duplicate person")
      expect(response.body).to include("Jane Doe")
    end

    it "renders the new form with duplicate warning and checkbox" do
      post people_path, params: {
        person: {
          first_name: "Jane",
          last_name: "Doe",
          email: "new@testmail.org",
          bio: "Test bio content",
          created_by_id: admin.id,
          updated_by_id: admin.id
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Test bio content")
      expect(response.body).to include("skip_duplicate_check")
      expect(response.body).to include("Create anyway")
    end

    it "does not show Create anyway button when duplicate is blocked (same name and email)" do
      post people_path, params: {
        person: { first_name: "Jane", last_name: "Doe", email: "jane.doe@example.com", created_by_id: admin.id, updated_by_id: admin.id }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Possible duplicate person")
      expect(response.body).to include("exact match")
      expect(response.body).not_to include("Create anyway")
      expect(response.body).not_to include("skip_duplicate_check")
    end

    it "creates the person with all params when Create anyway is submitted" do
      expect {
        post people_path, params: {
          skip_duplicate_check: "1",
          person: {
            first_name: "Jane",
            last_name: "Doe",
            email: "new@testmail.org",
            bio: "Full bio preserved",
            created_by_id: admin.id,
            updated_by_id: admin.id
          }
        }
      }.to change(Person, :count).by(1)

      created = Person.last
      expect(created.first_name).to eq("Jane")
      expect(created.last_name).to eq("Doe")
      expect(created.bio).to eq("Full bio preserved")
    end

    it "creates nested attributes when Create anyway is submitted" do
      sector = create(:sector, published: true)

      expect {
        post people_path, params: {
          skip_duplicate_check: "1",
          person: {
            first_name: "Jane",
            last_name: "Doe",
            email: "new@testmail.org",
            created_by_id: admin.id,
            updated_by_id: admin.id,
            sectorable_items_attributes: { "0" => { sector_id: sector.id, is_leader: "1", _destroy: "false" } }
          }
        }
      }.to change(Person, :count).by(1)

      created = Person.last
      expect(created.sectorable_items.count).to eq(1)
      expect(created.sectorable_items.first.sector).to eq(sector)
      expect(created.sectorable_items.first.is_leader).to be true
    end
  end

  context "when no duplicates are found" do
    it "creates the person normally" do
      expect {
        post people_path, params: {
          person: {
            first_name: "Unique",
            last_name: "Name",
            email: "unique@testmail.org",
            created_by_id: admin.id,
            updated_by_id: admin.id
          }
        }
      }.to change(Person, :count).by(1)
    end
  end
end
