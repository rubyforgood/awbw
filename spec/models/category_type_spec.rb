require 'rails_helper'

RSpec.describe CategoryType do
  # let(:category_type) { build(:category_type) } # Keep if needed

  describe 'associations' do
    it { should have_many(:categories).class_name("Category").dependent(:destroy) }
    it 'has the correct foreign key for categories' do
      expect(CategoryType.reflect_on_association(:categories).foreign_key.to_sym).to eq(:category_type_id)
    end
    it { should have_many(:categorizable_items).through(:categories).dependent(:destroy) }
  end

  describe 'validations' do
    let!(:existing_category_type) { create(:category_type) }
    subject { build(:category_type, name: existing_category_type.name) }
    it { should validate_presence_of(:name) }
  end

  describe 'scopes' do
    let!(:published_category_type) { create(:category_type, published: true) }
    let!(:unpublished_category_type) { create(:category_type, published: false) }

    it '.published returns only published category types' do
      expect(CategoryType.published).to include(published_category_type)
      expect(CategoryType.published).not_to include(unpublished_category_type)
    end
  end
end
