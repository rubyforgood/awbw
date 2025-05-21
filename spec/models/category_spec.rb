require 'rails_helper'

RSpec.describe Category do
  let(:category) { build(:category) }

  describe 'associations' do
    it { should belong_to(:metadatum) }
    it { should have_many(:categorizable_items).dependent(:destroy) }
    it { should have_many(:workshops).through(:categorizable_items) }
  end

  describe 'validations' do
    let!(:metadatum) { create(:metadatum) }
    let!(:existing_category) { create(:category, metadatum: metadatum) }
    subject { build(:category, name: existing_category.name, metadatum: metadatum) }
    it { should validate_presence_of(:name) }
  end

  describe 'associations' do
    it { should belong_to(:metadatum) }
    it { should have_many(:categorizable_items).dependent(:destroy) }
    it { should have_many(:workshops).through(:categorizable_items) }
  end
end 