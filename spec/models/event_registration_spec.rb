require "rails_helper"

RSpec.describe EventRegistration, type: :model do
  let!(:combined_perm) { create(:permission, :combined) }
  let!(:adult_perm) { create(:permission, :adult) }
  let!(:children_perm) { create(:permission, :children) }

  subject { create(:event_registration) }

  describe "associations" do
    it { should belong_to(:event).required }
    it { should belong_to(:registrant).required }
  end
end
