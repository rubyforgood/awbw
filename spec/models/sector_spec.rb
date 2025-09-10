# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Sector) do
  describe "associations" do
    it { is_expected.to(have_many(:sectorable_items).dependent(:destroy)) }
    it { is_expected.to(have_many(:workshops).through(:sectorable_items)) }
    it { is_expected.to(have_many(:quotes).through(:workshops)) }
  end

  describe "validations" do
    subject { build(:sector, name: existing_sector.name) }

    let!(:existing_sector) { create(:sector) }

    it { is_expected.to(validate_presence_of(:name)) }
  end
end
