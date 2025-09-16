require 'rails_helper'

RSpec.describe Facilitator, type: :model do
  describe 'associations' do
    it { should have_one(:user) }
    it { should have_many(:facilitator_organizations).dependent(:restrict_with_exception) }
    it { should have_many(:organizations).through(:facilitator_organizations) }
  end

  describe 'validations' do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:primary_email_address) }
    it { should validate_presence_of(:primary_email_address_type) }
    it { should validate_presence_of(:street_address) }
    it { should validate_presence_of(:city) }
    it { should validate_presence_of(:state) }
    it { should validate_presence_of(:zip) }
    it { should validate_presence_of(:country) }
    it { should validate_presence_of(:mailing_address_type) }
    it { should validate_presence_of(:phone_number) }
    it { should validate_presence_of(:phone_number_type) }
    it { should validate_inclusion_of(:primary_email_address_type).in_array(%w[Work Personal]) }
    it { should validate_inclusion_of(:mailing_address_type).in_array(%w[Work Personal]) }
    it { should validate_inclusion_of(:phone_number_type).in_array(%w[Work Personal]) }
  end
end
