require "rails_helper"

RSpec.describe "Membership tooltips", type: :request do
  let(:person) { create(:person) }
  let(:membership) { create(:membership, person: person) }

  it "shows action and status tooltips to an admin" do
    sign_in create(:user, :admin)

    get membership_path(membership)

    expect(response).to have_http_status(:ok)
    body = CGI.unescapeHTML(response.body)
    expect(body).to include("Creates the next year's invoice now. The ending invoice must be paid in full.")
    expect(body).to include("Stops future invoices. The current term remains in place.")
    expect(body).to include("Current membership covers today.")
  end

  it "shows payment and autopay tooltips to the member" do
    create(:membership_invoice, membership: membership, start_date: Date.current,
      end_date: Date.current + 1.year - 1.day, cost_cents: 10_000)
    sign_in create(:user, person: person)

    get person_path(person)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pays this invoice once. The card is not saved for automatic payments.")
    expect(response.body).to include("Saves a card and turns on automatic payments. Membership renewal is unchanged.")
    expect(response.body).to include("Automatic payments are off. Invoices must be paid manually.")
  end
end
