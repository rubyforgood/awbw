require "rails_helper"

RSpec.describe Admin::LeaderAffiliationsController, type: :routing do
  it "routes the review, its preview, and performing it" do
    expect(get: "/admin/leader_affiliations").to route_to("admin/leader_affiliations#index")
    expect(post: "/admin/leader_affiliations").to route_to("admin/leader_affiliations#confirm")
    expect(post: "/admin/leader_affiliations/perform").to route_to("admin/leader_affiliations#create")
  end
end
