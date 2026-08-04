require "rails_helper"

RSpec.describe AuthorCreditDivergencesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/author_credit_divergences").to route_to("author_credit_divergences#index")
    end

    it "routes to #update_person" do
      expect(patch: "/author_credit_divergences/update_person")
        .to route_to("author_credit_divergences#update_person")
    end

    it "routes to #update_item" do
      expect(patch: "/author_credit_divergences/update_item")
        .to route_to("author_credit_divergences#update_item")
    end
  end
end
