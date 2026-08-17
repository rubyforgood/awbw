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
    let(:old_address) { create(:address, addressable: old_org) }

    it "drops the stale address when the new org has several addresses" do
      create_list(:address, 2, addressable: new_org)
      affiliation = create(:affiliation, organization: old_org, organization_address: old_address)

      affiliation.update!(organization: new_org)

      expect(affiliation.reload.organization_id).to eq(new_org.id)
      expect(affiliation.organization_address_id).to be_nil
    end

    it "adopts the sole address of the new org" do
      new_address = create(:address, addressable: new_org)
      affiliation = create(:affiliation, organization: old_org, organization_address: old_address)

      affiliation.update!(organization: new_org)

      expect(affiliation.reload.organization_address_id).to eq(new_address.id)
    end

    it "clears the event registration link" do
      registration = create(:event_registration)
      affiliation = create(:affiliation, organization: old_org, event_registration: registration)

      affiliation.update!(organization: new_org)

      expect(affiliation.reload.event_registration_id).to be_nil
    end
  end
end
