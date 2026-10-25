require "rails_helper"

RSpec.describe "State field on address forms", type: :request do
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  def state_input
    Nokogiri::HTML(response.body).at_css("[name$='[state]']")
  end

  context "as the owner" do
    before do
      sign_in owner_user
      allow_any_instance_of(PersonPolicy).to receive(:edit?).and_return(true)
    end

    it "offers the US-state dropdown for a US address" do
      create(:address, addressable: person, state: "CA", country: "United States")

      get edit_person_path(person)

      expect(state_input.name).to eq("select")
      expect(state_input.at_css("option[selected]")["value"]).to eq("CA")
    end

    it "offers a text box for a non-USA address" do
      create(:address, addressable: person, state: "CA", country: "Canada")

      get edit_person_path(person)

      expect(state_input.name).to eq("input")
      expect(state_input["value"]).to eq("CA")
    end

    it "ignores admin=true" do
      create(:address, addressable: person, state: "CA", country: "United States")

      get edit_person_path(person, admin: true)

      expect(state_input.name).to eq("select")
    end
  end

  context "as an admin" do
    before { sign_in create(:user, super_user: true) }

    it "offers the dropdown for a US address" do
      create(:address, addressable: person, state: "CA", country: "United States")

      get edit_person_path(person)

      expect(state_input.name).to eq("select")
    end

    it "offers a text box with admin=true" do
      create(:address, addressable: person, state: "CA", country: "United States")

      get edit_person_path(person, admin: true)

      expect(state_input.name).to eq("input")
      expect(state_input["value"]).to eq("CA")
    end
  end

  context "on the organization form" do
    let(:organization) { create(:organization) }

    before { sign_in create(:user, super_user: true) }

    it "offers a text box for a non-USA address" do
      create(:address, addressable: organization, state: "CA", country: "Canada")

      get edit_organization_path(organization)

      expect(state_input.name).to eq("input")
      expect(state_input["value"]).to eq("CA")
    end
  end
end
