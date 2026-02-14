require "rails_helper"

RSpec.describe "/people/check_duplicates", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:existing_person) { create(:person, first_name: "Jane", last_name: "Doe", email: "jane.doe@example.com") }

  before do
    sign_in admin
  end

  describe "POST /people/check_duplicates" do
    context "when a duplicate name exists" do
      it "returns the duplicate person" do
        post check_duplicates_people_path, params: {
          first_name: "Jane",
          last_name: "Doe",
          email: ""
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response["duplicates"].length).to eq(1)
        expect(json_response["duplicates"][0]["name"]).to eq("Jane Doe")
      end

      it "is case insensitive" do
        post check_duplicates_people_path, params: {
          first_name: "JANE",
          last_name: "DOE",
          email: ""
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response["duplicates"].length).to eq(1)
      end
    end

    context "when a duplicate email exists" do
      it "returns the duplicate person" do
        post check_duplicates_people_path, params: {
          first_name: "",
          last_name: "",
          email: "jane.doe@example.com"
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response["duplicates"].length).to eq(1)
        expect(json_response["duplicates"][0]["email"]).to eq("jane.doe@example.com")
      end

      it "checks email_2 field" do
        person_with_email2 = create(:person, first_name: "John", last_name: "Smith", email: nil, email_2: "john.smith@example.com")
        
        post check_duplicates_people_path, params: {
          first_name: "",
          last_name: "",
          email: "john.smith@example.com"
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response["duplicates"].length).to eq(1)
        expect(json_response["duplicates"][0]["name"]).to eq("John Smith")
      end

      it "checks associated user email" do
        user = create(:user, email: "user@example.com")
        person_with_user = create(:person, first_name: "Bob", last_name: "Jones", email: nil, user: user)
        
        post check_duplicates_people_path, params: {
          first_name: "",
          last_name: "",
          email: "user@example.com"
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response["duplicates"].length).to eq(1)
        expect(json_response["duplicates"][0]["name"]).to eq("Bob Jones")
      end
    end

    context "when no duplicates exist" do
      it "returns an empty array" do
        post check_duplicates_people_path, params: {
          first_name: "NewFirst",
          last_name: "NewLast",
          email: "new@example.com"
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response["duplicates"]).to be_empty
      end
    end

    context "when both name and email match" do
      it "returns a single entry for the same person" do
        post check_duplicates_people_path, params: {
          first_name: "Jane",
          last_name: "Doe",
          email: "jane.doe@example.com"
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response["duplicates"].length).to eq(1)
      end
    end
  end
end
