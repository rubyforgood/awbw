# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Category) do
  let(:category) { build(:category) }

  describe "associations" do
    it { is_expected.to(belong_to(:metadatum)) }
    it { is_expected.to(have_many(:categorizable_items).dependent(:destroy)) }
    it { is_expected.to(have_many(:workshops).through(:categorizable_items)) }
  end

  describe "validations" do
    subject { build(:category, name: existing_category.name, metadatum: metadatum) }

    let!(:metadatum) { create(:metadatum) }
    let!(:existing_category) { create(:category, metadatum: metadatum) }

    it { is_expected.to(validate_presence_of(:name)) }
  end

  describe "associations" do
    it { is_expected.to(belong_to(:metadatum)) }
    it { is_expected.to(have_many(:categorizable_items).dependent(:destroy)) }
    it { is_expected.to(have_many(:workshops).through(:categorizable_items)) }
  end
end
