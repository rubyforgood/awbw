require "rails_helper"

RSpec.describe Events::PublicFormsController, type: :routing do
  describe "registration_form" do
    it "routes new" do
      expect(get: "/events/1/registration_form/new").to route_to(
        "events/public_forms#new", event_id: "1", form_role: "registration"
      )
    end

    it "routes create" do
      expect(post: "/events/1/registration_form").to route_to(
        "events/public_forms#create", event_id: "1", form_role: "registration"
      )
    end

    it "routes show" do
      expect(get: "/events/1/registration_form").to route_to(
        "events/public_forms#show", event_id: "1", form_role: "registration"
      )
    end
  end

  describe "scholarship_form" do
    it "routes new" do
      expect(get: "/events/1/scholarship_form/new").to route_to(
        "events/public_forms#new", event_id: "1", form_role: "scholarship"
      )
    end

    it "routes create" do
      expect(post: "/events/1/scholarship_form").to route_to(
        "events/public_forms#create", event_id: "1", form_role: "scholarship"
      )
    end
  end

  describe "bulk_payment_form" do
    it "routes new" do
      expect(get: "/events/1/bulk_payment_form/new").to route_to(
        "events/public_forms#new", event_id: "1", form_role: "bulk_payment"
      )
    end

    it "routes create" do
      expect(post: "/events/1/bulk_payment_form").to route_to(
        "events/public_forms#create", event_id: "1", form_role: "bulk_payment"
      )
    end
  end

  describe "ce_credit_form" do
    it "routes new" do
      expect(get: "/events/1/ce_credit_form/new").to route_to(
        "events/public_forms#new", event_id: "1", form_role: "ce_credit"
      )
    end

    it "routes create" do
      expect(post: "/events/1/ce_credit_form").to route_to(
        "events/public_forms#create", event_id: "1", form_role: "ce_credit"
      )
    end
  end

  it "does not collide with the registrant registrations route" do
    expect(post: "/events/1/registrations").to route_to(
      "events/registrations#create", event_id: "1"
    )
  end
end
