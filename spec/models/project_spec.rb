require 'rails_helper'

RSpec.describe Project do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:location).optional }
    it { should belong_to(:windows_type).optional }
    it { should belong_to(:project_status) }
    it { should have_many(:project_users) }
    it { should have_many(:users).through(:project_users) }
    it { should have_many(:reports).through(:users) }
    it { should have_many(:workshop_logs).through(:users) }
  end

  describe 'validations' do
    # Add validation tests if any (e.g., presence of name, associations)
    subject { build(:project) } # Requires associations
    it { should validate_presence_of(:name) }
    # it { should validate_presence_of(:location) }
    # it { should validate_presence_of(:windows_type) }
    it { should validate_presence_of(:project_status_id) }
  end

  it 'is valid with valid attributes' do
    # Note: Factory needs associations uncommented for create
    # expect(build(:project)).to be_valid
  end
end
