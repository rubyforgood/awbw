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
end 