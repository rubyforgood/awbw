require "rails_helper"

RSpec.describe Membership::Discard do
  let(:person) { create(:person, :without_user) }

  it "refuses a locked membership" do
    membership = create(:membership, person: person, locked_at: Time.current)

    result = described_class.call(membership: membership)

    expect(result).not_to be_success
    expect(result.errors.to_sentence).to match(/locked/)
    expect(membership.reload).to be_persisted
  end

  it "deletes an unlocked membership with a pristine invoice" do
    membership = create(:membership, person: person)
    create(:membership_invoice, membership: membership,
      start_date: membership.start_date, end_date: membership.end_date)

    result = described_class.call(membership: membership)

    expect(result).to be_success
    expect(Membership.exists?(membership.id)).to be(false)
  end
end
