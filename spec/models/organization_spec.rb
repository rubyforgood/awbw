require 'rails_helper'

RSpec.describe Organization do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:location).optional }
    it { should belong_to(:windows_type).optional }
    it { should belong_to(:organization_status) }
    it { should have_many(:affiliations) }
    it { should have_many(:users).through(:people) }
    it { should have_many(:reports) }
    it { should have_many(:workshop_logs) }
  end

  describe 'validations' do
    subject { build(:organization) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:organization_status_id) }

    it { should allow_value("info@example.com").for(:email) }
    it { should allow_value("").for(:email) }
    it { should allow_value(nil).for(:email) }
    it { should_not allow_value("not-an-email").for(:email).with_message("must be a valid email address") }
  end

  it 'is valid with valid attributes' do
    # Note: Factory needs associations uncommented for create
    # expect(build(:organization)).to be_valid
  end
end
