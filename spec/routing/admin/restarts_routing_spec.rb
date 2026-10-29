require "rails_helper"

RSpec.describe Admin::RestartsController, type: :routing do
  it "routes GET /admin/restart to #show" do
    expect(get: "/admin/restart").to route_to("admin/restarts#show")
  end

  it "routes POST /admin/restart to #create" do
    expect(post: "/admin/restart").to route_to("admin/restarts#create")
  end
end
