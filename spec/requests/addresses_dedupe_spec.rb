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
    let(:admin) { create(:user, :admin) }

    before { sign_in admin }

    it "lists owners with duplicate addresses" do
      get dedupe_index_addresses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Duplicate Org", person.full_name, "Merge 1 duplicate", "Merge 2 duplicates", "Merge all (3)")
      expect(response.body.scan(">Keep<").size).to eq(2)
      expect(response.body.scan("Preview merge").size).to eq(3)
    end

    it "merges one owner's duplicates" do
      contact_method = create(:contact_method, contactable: org, address: org_addresses.last)

      post dedupe_perform_owner_addresses_path, params: { addressable_sgid: sgid(org) }

      expect(response).to redirect_to(dedupe_index_addresses_path)
      expect(flash[:notice]).to include("1 duplicate address")
      expect(org.addresses.reload).to eq([ org_addresses.first ])
      expect(contact_method.reload.address).to eq(org_addresses.first)
      expect(person.addresses.count).to eq(3)
    end

    it "merges nothing without a record" do
      post dedupe_perform_owner_addresses_path

      expect(flash[:alert]).to include("Error merging addresses")
      expect(org.addresses.count).to eq(2)
      expect(person.addresses.count).to eq(3)
    end

    it "queues a background merge of every record, run as the admin" do
      expect { post dedupe_perform_all_addresses_path }.to have_enqueued_job(MergeDuplicateAddressesJob).with(admin)

      expect(response).to redirect_to(dedupe_index_addresses_path)
      expect(flash[:notice]).to include("in the background")
      expect(org.addresses.count).to eq(2)
    end

    it "rejects a signed id minted for another purpose" do
      post dedupe_perform_owner_addresses_path, params: { addressable_sgid: org.to_sgid.to_s }

      expect(flash[:alert]).to include("Error merging addresses")
      expect(org.addresses.count).to eq(2)
    end
  end

  context "as a regular user" do
    before { sign_in create(:user) }

    it "denies the page and the merge" do
      get dedupe_index_addresses_path
      expect(response).to redirect_to(root_path)

      post dedupe_perform_owner_addresses_path
      expect(response).to redirect_to(root_path)
      expect(org.addresses.count).to eq(2)

      expect { post dedupe_perform_all_addresses_path }.not_to have_enqueued_job(MergeDuplicateAddressesJob)
    end
  end

  it "shows a back link on the profile it linked to" do
    sign_in create(:user, :admin)

    get organization_path(org, return_to: "address_dedupe", anchor_id: "address-dedupe-organization-#{org.id}")

    expect(response.body).to include("Back to dedupe addresses", "#address-dedupe-organization-#{org.id}")
  end
end
