require "rails_helper"

RSpec.describe "Login search across every access status", type: :request do
  let(:admin) { create(:user, :admin) }

  describe "GET /search/user_any_status" do
    let!(:active) { create(:user, email: "pat.active@example.com") }
    let!(:unconfirmed) { create(:user, :unconfirmed, email: "pat.unconfirmed@example.com") }
    let!(:locked) { create(:user, :locked, email: "pat.locked@example.com") }
    let!(:inactive) { create(:user, email: "pat.inactive@example.com", inactive: true) }

    it "finds logins that can't sign in, labelled with their status" do
      sign_in admin

      get "/search/user_any_status", params: { q: "pat." }

      labels = response.parsed_body.to_h { |row| [ row["id"], row["label"] ] }
      expect(labels[active.id]).to eq(active.full_name_with_email)
      expect(labels[unconfirmed.id]).to eq("#{unconfirmed.full_name_with_email} · Unconfirmed")
      expect(labels[locked.id]).to eq("#{locked.full_name_with_email} · Locked")
      expect(labels[inactive.id]).to eq("#{inactive.full_name_with_email} · Inactive")
    end

    it "is forbidden to a non-admin" do
      sign_in create(:user)

      get "/search/user_any_status", params: { q: "pat." }

      expect(response).to redirect_to(root_path)
    end
  end
end
