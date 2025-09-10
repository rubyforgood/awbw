# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Metadatum) do
  # let(:metadatum) { build(:metadatum) } # Keep if needed

  describe "associations" do
    it { is_expected.to(have_many(:categories).dependent(:destroy)) }
    it { is_expected.to(have_many(:categorizable_items).through(:categories).dependent(:destroy)) }
  end

  describe "validations" do
    subject { build(:metadatum, name: existing_metadatum.name) }

    let!(:existing_metadatum) { create(:metadatum) }

    it { is_expected.to(validate_presence_of(:name)) }
  end

  describe "scopes" do
    let!(:published_meta) { create(:metadatum, published: true) }
    let!(:unpublished_meta) { create(:metadatum, published: false) }

    it ".published returns only published metadata" do
      expect(described_class.published).to(include(published_meta))
      expect(described_class.published).not_to(include(unpublished_meta))
    end
  end
end
