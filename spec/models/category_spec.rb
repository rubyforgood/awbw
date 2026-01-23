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

    it "validates position is an integer" do
      category = build(:category, position: "not a number")
      expect(category).not_to be_valid
      expect(category.errors[:position]).to be_present
    end

    it "allows nil position" do
      category = build(:category, position: nil)
      expect(category).to be_valid
    end

    it "allows integer position" do
      category = build(:category, position: 5)
      expect(category).to be_valid
    end
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

  describe "ordering by position and name" do
    let!(:category_type) { create(:category_type) }

    it "orders categories by position first, then by name" do
      cat_c_pos_30 = create(:category, name: "C Category", position: 30, category_type: category_type)
      cat_a_pos_1 = create(:category, name: "A Category", position: 1, category_type: category_type)
      cat_b_pos_1 = create(:category, name: "B Category", position: 1, category_type: category_type)
      cat_d_pos_20 = create(:category, name: "D Category", position: 20, category_type: category_type)

      # Using COALESCE to place NULL values last
      categories = Category.where(category_type: category_type)
                           .order(Arel.sql("categories.position, categories.name"))

      # The order should be: position 1 in name order (A, B), then position 2 (C), then nil (D)
      expect(categories.to_a).to eq([ cat_a_pos_1, cat_b_pos_1, cat_d_pos_20, cat_c_pos_30 ])
    end
  end
end
