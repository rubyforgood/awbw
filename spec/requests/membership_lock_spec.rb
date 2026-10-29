require "rails_helper"

RSpec.describe "Membership lock", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner) { create(:user, :with_person) }
  let(:membership) { create(:membership, person: owner.person) }

  it "lets an admin unlock a locked membership" do
    membership.update_column(:locked_at, Time.current)
    sign_in admin

    delete membership_lock_path(membership)

    expect(response).to redirect_to(membership_path(membership))
    expect(membership.reload.locked_at).to be_nil
    expect(flash[:notice]).to match(/unlocked/)
  end

  it "denies the owner" do
    membership.update_column(:locked_at, Time.current)
    sign_in owner

    delete membership_lock_path(membership)

    expect(response).to redirect_to(root_path)
    expect(membership.reload.locked_at).to be_present
  end
end
