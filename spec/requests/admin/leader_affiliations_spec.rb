require "rails_helper"

RSpec.describe "Admin::LeaderAffiliations", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let!(:twin) { create(:affiliation, person:, organization:, title: "Facilitator") }
  let!(:leader) { create(:affiliation, person:, organization:, title: "Leader") }

  it "keeps non-admins out" do
    sign_in create(:user)

    get admin_leader_affiliations_path

    expect(response).to redirect_to(root_path)
  end

  describe "as an admin" do
    before { sign_in admin }

    it "lists each Leader row with its suggested choice selected" do
      get admin_leader_affiliations_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Facilitator ##{twin.id}")
      expect(response.body).to match(/id="outcome_#{leader.id}_merge"[^>]*checked|checked[^>]*id="outcome_#{leader.id}_merge"/)
    end

    it "previews the chosen changes without making them" do
      post admin_leader_affiliations_path, params: { outcome: { leader.id.to_s => "merge" } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Merge into Facilitator (1)")
      expect(Affiliation.exists?(leader.id)).to be(true)
    end

    it "sends an empty choice back to the page" do
      post admin_leader_affiliations_path, params: { outcome: { leader.id.to_s => "keep" } }

      expect(response).to redirect_to(admin_leader_affiliations_path(outcome: { leader.id.to_s => "keep" }))
    end

    it "performs the confirmed changes" do
      post admin_perform_leader_affiliations_path, params: { outcome: { leader.id.to_s => "merge" } }

      expect(response).to redirect_to(admin_leader_affiliations_path)
      expect(Affiliation.exists?(leader.id)).to be(false)
      expect(twin.reload.primary_contact).to be(true)
    end
  end
end
