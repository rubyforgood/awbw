require 'rails_helper'

RSpec.describe Sector do
  describe 'associations' do
    it { should have_many(:sectorable_items).dependent(:destroy) }
    it { should have_many(:workshops).through(:sectorable_items) }
    it { should have_many(:quotes).through(:workshops) }
  end

  describe 'validations' do
    let!(:existing_sector) { create(:sector) }
    subject { build(:sector, name: existing_sector.name) }
    it { should validate_presence_of(:name) }
  end

  it "has a valid factory" do
    expect(build(:sector)).to be_valid
  end

  describe ".published" do
    it "returns only published sectors" do
      published = create(:sector, published: true)
      unpublished = create(:sector, published: false)

      expect(Sector.published).to contain_exactly(published)
    end
  end
end
