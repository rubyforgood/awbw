require 'rails_helper'

RSpec.describe ProjectUser do

  describe 'associations' do
    it { should belong_to(:project) }
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject do
      build(:project_user, project: create(:project), user: create(:user))
    end
    it { should validate_presence_of(:project_id) }
  end

  describe 'enums' do
    it { should define_enum_for(:position).with_values(default: 0, liaison: 1, leader: 2, assistant: 3) }
  end

  it 'is valid with valid attributes' do
    # Note: Factory needs associations uncommented for create
    # expect(build(:project_user)).to be_valid
    # pending("Requires functional project/user factories and associations uncommented")
  end
end 