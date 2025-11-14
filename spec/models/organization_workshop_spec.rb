require 'rails_helper'

RSpec.describe OrganizationWorkshop, type: :model do
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:workshop) }
  end
end