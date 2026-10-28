class IssueMembershipInvoicesJob < ApplicationJob
  queue_as :default

  def perform
    return unless Membership.enabled?

    Time.use_zone(Membership::TIME_ZONE) do
      expiring_memberships.find_each do |membership|
        Membership::Renew.call(membership: membership)
      end
    end
  end

  private

  def expiring_memberships
    Membership
      .unlocked
      .where(autorenewal_cancelled_at: nil)
      .where(end_date: (Date.current - 1.day)..(Date.current + Membership.renewal_window_days))
      .includes(:membership_invoices)
  end
end
