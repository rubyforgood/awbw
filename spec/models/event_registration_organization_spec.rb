require "rails_helper"

RSpec.describe EventRegistrationOrganization, type: :model do
  describe "associations" do
    it { should belong_to(:event_registration).required }
    it { should belong_to(:organization).required }
  end

  describe "validations" do
    subject { create(:event_registration_organization) }

    it { should validate_uniqueness_of(:organization_id).scoped_to(:event_registration_id) }
  end
end
