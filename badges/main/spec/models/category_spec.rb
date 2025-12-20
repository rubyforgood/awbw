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

  it "belongs to a category_type" do
    expect(described_class.reflect_on_association(:category_type)).to be_present
  end

  describe ".published" do
    it "returns only published categories" do
      visible = create(:category, published: true)
      hidden  = create(:category, published: false)

      expect(Category.published).to contain_exactly(visible)
    end
  end
end 