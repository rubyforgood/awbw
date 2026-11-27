require "rails_helper"

RSpec.describe "Dedupe picker search", type: :request do
  let(:admin) { create(:user, :admin) }

  def ids_for(model, query)
    get "/search/#{model}_dedupe", params: { q: query }
    response.parsed_body.map { |row| row["id"] }
  end

  context "as an admin" do
    before { sign_in admin }

    describe "people" do
      let!(:coded) { create(:person, first_name: "Coded", last_name: "Person", filemaker_code: "P100, P123") }
      let!(:named) { create(:person, first_name: "P123", last_name: "Lookalike") }

      it "finds a person by any of their FileMaker codes, ahead of name matches" do
        expect(ids_for(:person, "P123")).to eq([ coded.id, named.id ])
      end

      it "matches a whole FileMaker code only" do
        expect(ids_for(:person, "P12")).not_to include(coded.id)
      end

      it "finds a person by portal id, labelled with it" do
        ids_for(:person, coded.id.to_s)

        row = response.parsed_body.first
        expect(row["id"]).to eq(coded.id)
        expect(row["label"]).to end_with("· ##{coded.id}")
      end

      it "still finds people by name" do
        expect(ids_for(:person, "Lookalike")).to eq([ named.id ])
      end
    end

    it "finds an organization by FileMaker code or portal id" do
      organization = create(:organization, name: "Harbor House", filemaker_code: "O555")

      expect(ids_for(:organization, "O555")).to eq([ organization.id ])
      expect(ids_for(:organization, organization.id.to_s)).to eq([ organization.id ])
    end

    it "finds a record without FileMaker codes by portal id" do
      category = create(:category)

      expect(ids_for(:category, category.id.to_s)).to eq([ category.id ])
    end

    it "finds a login of any access status by portal id" do
      user = create(:user, :locked)

      expect(ids_for(:user_any_status, user.id.to_s)).to include(user.id)
    end

    it "hints what the pickers match" do
      get dedupe_index_people_path
      expect(response.body).to include("Search by name, email, FileMaker code, or portal ID")

      get dedupe_index_organizations_path
      expect(response.body).to include("Search by name, FileMaker code, or portal ID")

      get dedupe_index_categories_path
      expect(response.body).to include("Search by name or portal ID")

      get dedupe_index_workshops_path
      expect(response.body).to include("Search by title, FileMaker code, or portal ID")
    end

    it "rejects an unknown model" do
      get "/search/secret_dedupe", params: { q: "1" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  it "is forbidden to a non-admin" do
    sign_in create(:user)

    get "/search/person_dedupe", params: { q: "P123" }

    expect(response).to redirect_to(root_path)
  end
end
