require 'rails_helper'

RSpec.describe CategorizableItem do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:category) }
    it { should belong_to(:categorizable) } # Polymorphic
  end

  describe 'validations' do
    # Now that validations are enabled, test them
    subject { build(:categorizable_item) }
    it { should validate_presence_of(:category_id) }
    it { should validate_presence_of(:categorizable_id) }
    it { should validate_presence_of(:categorizable_type) }
    # Uniqueness requires create and proper scoping:
    it { should validate_uniqueness_of(:category_id).scoped_to([ :categorizable_type, :categorizable_id ]) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs category and categorizable associations uncommented for create
  #   # Example with workshop:
  #   # workshop = create(:workshop)
  #   # category = create(:category) # Needs metadatum
  #   # expect(build(:categorizable_item, categorizable: workshop, category: category)).to be_valid
  #   pending("Requires functional category/workshop factories and associations uncommented")
  # end
end
