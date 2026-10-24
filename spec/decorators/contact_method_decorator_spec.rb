require "rails_helper"

RSpec.describe ContactMethodDecorator do
  describe "#dedupe_label" do
    it "names the method kind with its value" do
      contact_method = build(:contact_method, kind: "whatsapp", value: "555-0100")
      expect(contact_method.decorate.dedupe_label).to eq("Whatsapp · 555-0100")
    end
  end
end
