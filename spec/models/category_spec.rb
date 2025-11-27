require 'rails_helper'

RSpec.describe Category do
  let(:category) { build(:category) }

  describe 'associations' do
    it { should belong_to(:category_type) }
    it { should have_many(:categorizable_items).dependent(:destroy) }
    it { should have_many(:workshops).through(:categorizable_items) }
  end

  describe 'validations' do
    let!(:category_type) { create(:category_type) }
    let!(:existing_category) { create(:category, category_type: category_type) }
    subject { build(:category, name: existing_category.name, category_type: category_type) }
    it { should validate_presence_of(:name) }
  end

  describe 'associations' do
    it { should belong_to(:category_type) }
    it { should have_many(:categorizable_items).dependent(:destroy) }
    it { should have_many(:workshops).through(:categorizable_items) }
  end
end 