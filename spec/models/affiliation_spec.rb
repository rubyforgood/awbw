require "rails_helper"

RSpec.describe Affiliation, type: :model do
  describe "comments" do
    it "holds comments as the polymorphic commentable" do
      affiliation = create(:affiliation)
      comment = affiliation.comments.create!(body: "A note about this affiliation")

      expect(comment.commentable).to eq(affiliation)
    end
  end

  describe "lifecycle tracking" do
    it "buffers an update.affiliation ahoy event when edited by a user" do
      affiliation = create(:affiliation, title: "Facilitator")
      Current.user = create(:user, :admin)
      allow(Analytics::LifecycleBuffer).to receive(:push).and_call_original

      affiliation.update!(title: "Lead facilitator")

      expect(Analytics::LifecycleBuffer).to have_received(:push)
        .with(hash_including(name: "update.affiliation"))
    end
  end

  describe "reassigning the organization" do
    let(:old_org) { create(:organization) }
    let(:new_org) { create(:organization) }
    let(:address) { create(:address, addressable: old_org) }

    it "clears the org-scoped address so the row survives validation" do
      affiliation = create(:affiliation, organization: old_org, organization_address: address)

      affiliation.update!(organization: new_org)

      expect(affiliation.reload.organization_id).to eq(new_org.id)
      expect(affiliation.organization_address_id).to be_nil
    end
  end
end
