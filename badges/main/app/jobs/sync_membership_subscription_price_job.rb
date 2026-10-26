class SyncMembershipSubscriptionPriceJob < ApplicationJob
  queue_as :default

  def perform(membership_id)
    membership = Membership.find_by(id: membership_id)
    return if membership.blank?

    Membership::SyncSubscriptionPrice.call(membership:)
  end
end
