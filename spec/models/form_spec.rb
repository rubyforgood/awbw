require 'rails_helper'

RSpec.describe Form do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:owner) } # Polymorphic
    it { should have_many(:form_fields).dependent(:destroy).inverse_of(:form) }
    it { should have_many(:user_forms) }
    it { should have_many(:reports) } # As :owner

    it { should accept_nested_attributes_for(:form_fields).allow_destroy(true) }
  end

  describe 'validations' do
    # Add validation tests if any
    # subject { build(:form) } # Requires owner
    # it { should validate_presence_of(:owner_id) }
    # it { should validate_presence_of(:owner_type) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs owner association uncommented for create
  #   # expect(build(:form)).to be_valid
  #   pending("Requires functional owner factory and association uncommented")
  # end

  describe '#display_name' do
    let(:user_owner) do
      create(:user)
    end
    let(:form) { build(:form, owner: user_owner) }

    context 'when name is set' do
      it 'returns the name' do
        form.name = "Public Registration"
        expect(form.display_name).to eq("Public Registration")
      end
    end

    context 'when name is blank and owner is present' do
      it 'returns owner name Form' do
        form.name = nil
        owner_name = user_owner.try(:name) || user_owner.email
        expect(form.display_name).to eq("#{owner_name} Form")
      end
    end

    context 'when name is blank and owner is nil' do
      it 'returns New Form' do
        form.name = nil
        form.owner = nil
        expect(form.display_name).to eq('New Form')
      end
    end
  end
end
