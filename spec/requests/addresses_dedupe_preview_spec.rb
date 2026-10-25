# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Address dedupe preview", type: :request do
  let(:attrs) do
    {
      street_address: "1 Main St", city: "Springfield", state: "CA", zip_code: "90001",
      country: "United States", county: "LA", address_type: "work", locality: "LA City"
    }
  end
  let(:org) { create(:organization) }
  let!(:keep) { create(:address, addressable: org, **attrs, phone: nil) }
  let!(:dupe) { create(:address, addressable: org, **attrs, phone: "555-0100", primary: true, invoice_address: true) }

  def preview_params(keep_id: keep.id, delete_id: dupe.id)
    { address_to_keep_id: keep_id, address_to_delete_id: delete_id }
  end

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    it "links each copy that merges away to its preview" do
      get dedupe_index_addresses_path

      expect(response.body).to include(CGI.escapeHTML(dedupe_preview_addresses_path(
        address_to_delete_id: keep.id, address_to_keep_id: dupe.id, anchor_id: "address-dedupe-organization-#{org.id}"
      )))
    end

    it "shows both copies side by side with what the merge fills in" do
      get dedupe_preview_addresses_path(preview_params)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Preview address merge", "Address to delete", "Address to keep", "555-0100")
      expect(response.body).to include("On merge: Fills in from the deleted copy")
      expect(response.body).to include("On merge: Becomes the primary address")
      expect(response.body).not_to include("Merge blocked")
    end

    it "blocks a merge across two owners" do
      other = create(:address, addressable: create(:organization), **attrs)

      get dedupe_preview_addresses_path(preview_params(delete_id: other.id))

      expect(response.body).to include("Merge blocked", "belong to different records")
    end

    it "merges the pair, filling the keeper's blanks and moving what pointed at the copy" do
      contact_method = create(:contact_method, contactable: org, address: dupe)
      anchor = "address-dedupe-organization-#{org.id}"

      post dedupe_perform_addresses_path, params: preview_params.merge(anchor_id: anchor)

      expect(response).to redirect_to(dedupe_index_addresses_path(anchor: anchor))
      expect(Address.exists?(dupe.id)).to be(false)
      expect(keep.reload).to have_attributes(phone: "555-0100", primary: true, invoice_address: true)
      expect(contact_method.reload.address).to eq(keep)
    end

    it "refuses a merge across two owners" do
      other = create(:address, addressable: create(:organization), **attrs)

      post dedupe_perform_addresses_path, params: preview_params(delete_id: other.id)

      expect(flash[:alert]).to include("belong to different records")
      expect(Address.exists?(other.id)).to be(true)
    end

    it "saves an edit to the keeper as it's made" do
      patch dedupe_update_keep_addresses_path, params: { id: keep.id, address_to_keep: { phone: "555-0199" } }

      expect(response).to have_http_status(:ok)
      expect(keep.reload.phone).to eq("555-0199")
    end
  end

  context "as a regular user" do
    before { sign_in create(:user) }

    it "denies the preview and the merge" do
      get dedupe_preview_addresses_path(preview_params)
      expect(response).to redirect_to(root_path)

      post dedupe_perform_addresses_path, params: preview_params
      expect(Address.exists?(dupe.id)).to be(true)
    end
  end
end
