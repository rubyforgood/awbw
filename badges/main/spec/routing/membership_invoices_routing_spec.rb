require "rails_helper"

RSpec.describe "Membership invoices routing", type: :routing do
  it "routes the actions it has" do
    expect(get: "/membership_invoices").to route_to("membership_invoices#index")
    expect(get: "/membership_invoices/1").to route_to("membership_invoices#show", id: "1")
    expect(get: "/membership_invoices/1/edit").to route_to("membership_invoices#edit", id: "1")
    expect(patch: "/membership_invoices/1").to route_to("membership_invoices#update", id: "1")
    expect(get: "/membership_invoices/1/receipt").to route_to("membership_invoices#receipt", id: "1")
    expect(get: "/memberships/1/membership_invoices/new").to route_to("membership_invoices#new", membership_id: "1")
    expect(post: "/memberships/1/membership_invoices").to route_to("membership_invoices#create", membership_id: "1")
    expect(delete: "/membership_invoices/1").to route_to("membership_invoices#destroy", id: "1")
  end
end
