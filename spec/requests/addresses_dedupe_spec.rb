# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Address dedupe", type: :request do
  let(:attrs) do
    {
      street_address: "1 Main St", city: "Springfield", state: "CA", zip_code: "90001",
      country: "USA", county: "LA", district: nil, address_type: "work", locality: "LA City"
    }
  end
  let(:org) { create(:organization, name: "Duplicate Org") }
  let(:person) { create(:person) }
  let!(:org_addresses) { create_list(:address, 2, addressable: org, **attrs) }
  let!(:person_addresses) { create_list(:address, 3, addressable: person, **attrs) }

  def sgid(record)
    record.to_sgid(for: AddressesController::DEDUPE_PURPOSE).to_s
  end

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    it "lists owners with duplicate addresses" do
      get dedupe_index_addresses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Duplicate Org", person.full_name, "Fold all (3)")
    end

    it "folds one owner's duplicates" do
      contact_method = create(:contact_method, contactable: org, address: org_addresses.last)

      post dedupe_perform_addresses_path, params: { addressable_sgid: sgid(org) }

      expect(response).to redirect_to(dedupe_index_addresses_path)
      expect(flash[:notice]).to include("1 duplicate address")
      expect(org.addresses.reload).to eq([ org_addresses.first ])
      expect(contact_method.reload.address).to eq(org_addresses.first)
      expect(person.addresses.count).to eq(3)
    end

    it "folds every owner when no record is given" do
      post dedupe_perform_addresses_path

      expect(flash[:notice]).to include("3 duplicate addresses across 2 records")
      expect(org.addresses.count).to eq(1)
      expect(person.addresses.count).to eq(1)
    end

    it "rejects a signed id minted for another purpose" do
      post dedupe_perform_addresses_path, params: { addressable_sgid: org.to_sgid.to_s }

      expect(flash[:alert]).to include("Error folding addresses")
      expect(org.addresses.count).to eq(2)
    end
  end

  context "as a regular user" do
    before { sign_in create(:user) }

    it "denies the page and the fold" do
      get dedupe_index_addresses_path
      expect(response).to redirect_to(root_path)

      post dedupe_perform_addresses_path
      expect(response).to redirect_to(root_path)
      expect(org.addresses.count).to eq(2)
    end
  end

  it "shows a back link on the profile it linked to" do
    sign_in create(:user, :admin)

    get organization_path(org, return_to: "address_dedupe", anchor_id: "address-dedupe-organization-#{org.id}")

    expect(response.body).to include("Back to dedupe addresses", "#address-dedupe-organization-#{org.id}")
  end
end
