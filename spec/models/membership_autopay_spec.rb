require "rails_helper"

RSpec.describe Membership, type: :model do
  it "turns autopay off when the membership is locked for history" do
    membership = create(:membership, autopay_on: true)

    membership.lock_for_history!

    expect(membership.reload.autopay_on?).to be(false)
  end
end
