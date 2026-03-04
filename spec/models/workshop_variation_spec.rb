require 'rails_helper'

RSpec.describe WorkshopVariation do
  it_behaves_like "author_creditable", factory: :workshop_variation

  describe 'associations' do
    it { should belong_to(:workshop).optional }
  end

  describe 'validations' do
    # Add validation tests if any (e.g., presence of name, code?)
    # subject { build(:workshop_variation) } # Requires workshop
    # it { should validate_presence_of(:name) }
    # it { should validate_presence_of(:code) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs association uncommented for create
  #   # expect(build(:workshop_variation)).to be_valid
  #   pending("Requires functional workshop factory and association uncommented")
  # end

  describe '.search_by_params' do
    let!(:variation_a) { create(:workshop_variation, name: 'Watercolor Technique') }
    let!(:variation_b) { create(:workshop_variation, name: 'Clay Sculpting') }

    it 'returns all when no params' do
      results = WorkshopVariation.search_by_params({})
      expect(results).to include(variation_a, variation_b)
    end

    it 'filters by query matching name' do
      results = WorkshopVariation.search_by_params(query: 'Watercolor')
      expect(results).to include(variation_a)
      expect(results).not_to include(variation_b)
    end

    it 'returns empty for non-matching query' do
      results = WorkshopVariation.search_by_params(query: 'nonexistent')
      expect(results).not_to include(variation_a, variation_b)
    end
  end
end
