require "rails_helper"

RSpec.describe "People memberships", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  before { sign_in admin }

  describe "GET /people/:person_id/memberships/new" do
    it "leaves the first invoice amount blank so the locked price can apply" do
      get new_person_membership_path(person)

      expect(response).to have_http_status(:ok)
      field = Nokogiri::HTML(response.body)
        .at_css("input[name='membership[first_invoice_cost_dollars]']")
      expect(field["value"]).to be_nil
    end
  end

  describe "POST /people/:person_id/memberships" do
    def create_membership(cost: "", first_invoice: "")
      post person_memberships_path(person), params: {
        membership: {
          start_date: Date.current.to_s,
          cost_dollars: cost,
          first_invoice_cost_dollars: first_invoice
        }
      }
    end

    it "bills the locked price for the first invoice when no amount is entered" do
      expect { create_membership(cost: "50") }.to change(Membership, :count).by(1)

      membership = person.memberships.sole
      expect(membership.cost_cents).to eq(5_000)
      expect(membership.membership_invoices.sole.cost_cents).to eq(5_000)
      expect(response).to redirect_to(membership_path(membership))
    end

    it "lets an explicit first invoice amount override the locked price" do
      create_membership(cost: "50", first_invoice: "75")

      membership = person.memberships.sole
      expect(membership.cost_cents).to eq(5_000)
      expect(membership.membership_invoices.sole.cost_cents).to eq(7_500)
    end

    it "comps a zero first invoice" do
      create_membership(cost: "50", first_invoice: "0")

      expect(person.memberships.sole.membership_invoices.sole.cost_cents).to eq(0)
    end

    it "rejects a non-numeric amount without creating a membership" do
      expect { create_membership(cost: "fifty") }.not_to change(Membership, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Enter the locked price and first invoice as numbers")
    end

    it "rejects a negative amount" do
      expect { create_membership(first_invoice: "-5") }.not_to change(Membership, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
