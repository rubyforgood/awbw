require 'rails_helper'

RSpec.describe SectorableItem do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:sector) }
    it { should belong_to(:sectorable) } # Polymorphic
  end

  describe 'validations' do
    subject { build(:sectorable_item) }
    it { should validate_presence_of(:sector_id) }
    it { should validate_uniqueness_of(:sector_id).scoped_to([ :sectorable_type, :sectorable_id ]).with_message("has already been added") }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs associations uncommented for create
  #   # expect(build(:sectorable_item)).to be_valid
  #   pending("Requires functional sector/sectorable factories and associations uncommented")
  # end
end
