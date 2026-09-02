require "rails_helper"

RSpec.describe Honeypot do
  def params_with(scope_attrs)
    ActionController::Parameters.new(contact_us: scope_attrs)
  end

  describe ".tripped?" do
    it "is true when the decoy field carries a value" do
      expect(described_class.tripped?(params_with(described_class::FIELD_NAME => "spam"), :contact_us)).to be(true)
    end

    it "is false when the decoy field is blank, as a human always leaves it" do
      expect(described_class.tripped?(params_with(described_class::FIELD_NAME => ""), :contact_us)).to be(false)
    end

    it "is true when the decoy field is absent, since our form always renders it" do
      expect(described_class.tripped?(params_with(message: "hello"), :contact_us)).to be(true)
    end

    it "is true when the whole scope is missing, as a real submission never omits it" do
      expect(described_class.tripped?(ActionController::Parameters.new, :contact_us)).to be(true)
    end
  end

  describe "FIELD_NAME" do
    it "names nothing the portal actually stores, so a real answer can't read as spam" do
      [ Person, Organization, Story, FormField ].each do |model|
        expect(model.column_names).not_to include(described_class::FIELD_NAME)
      end
    end

    it "is not a FormField identifier any form could collect" do
      expect(FormField.distinct.pluck(:field_identifier).compact).not_to include(described_class::FIELD_NAME)
    end
  end
end
