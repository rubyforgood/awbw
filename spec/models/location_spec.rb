# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Location) do
  # let(:location) { build(:location) } # Keep if needed

  describe "validations" do
    subject { build(:location) }

    it { is_expected.to(validate_presence_of(:city)) }
    it { is_expected.to(validate_presence_of(:country)) }
  end

  describe "#name" do
    it "returns the city and state" do
      # Use attributes_for to easily access factory-generated values
      attrs = attributes_for(:location)
      location = build(:location, attrs)
      expect(location.name).to(eq("#{attrs[:city]}, #{attrs[:state]}"))
    end
  end
end
