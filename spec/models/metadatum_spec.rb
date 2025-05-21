require 'rails_helper'

RSpec.describe Metadatum do
  # let(:metadatum) { build(:metadatum) } # Keep if needed

  describe 'associations' do
    it { should have_many(:categories).dependent(:destroy) }
    it { should have_many(:categorizable_items).through(:categories).dependent(:destroy) }
  end

  describe 'validations' do
    let!(:existing_metadatum) { create(:metadatum) }
    subject { build(:metadatum, name: existing_metadatum.name) }
    it { should validate_presence_of(:name) }
  end

  describe 'scopes' do
    let!(:published_meta) { create(:metadatum, published: true) }
    let!(:unpublished_meta) { create(:metadatum, published: false) }

    it '.published returns only published metadata' do
      expect(Metadatum.published).to include(published_meta)
      expect(Metadatum.published).not_to include(unpublished_meta)
    end
  end
end 