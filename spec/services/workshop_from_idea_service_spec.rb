require "rails_helper"

RSpec.describe WorkshopFromIdeaService do
  let(:admin) { create(:user, :admin) }
  let(:organization) { create(:organization) }
  let(:windows_type) { create(:windows_type) }

  describe "#call" do
    it "copies organization_id from the workshop_idea to the initialized workshop" do
      idea = create(:workshop_idea, organization: organization, windows_type: windows_type)

      workshop = described_class.new(idea, user: admin).call

      expect(workshop.organization_id).to eq(organization.id)
      expect(workshop.organization).to eq(organization)
      expect(workshop.workshop_idea_id).to eq(idea.id)
    end

    it "sets organization_id to nil when workshop_idea has no organization" do
      idea = create(:workshop_idea, organization: nil, windows_type: windows_type)

      workshop = described_class.new(idea, user: admin).call

      expect(workshop.organization_id).to be_nil
    end
  end
end
