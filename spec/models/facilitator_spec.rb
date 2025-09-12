require 'rails_helper'

RSpec.describe Facilitator, type: :model do
  describe 'associations' do
    it { should have_one(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
  end
end
