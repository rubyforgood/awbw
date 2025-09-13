require 'rails_helper'

RSpec.describe FacilitatorOrganization, type: :model do
  describe 'associations' do
    it { should belong_to(:facilitator) }
    it { should belong_to(:organization) }
  end
end