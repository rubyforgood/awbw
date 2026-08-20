class IssueMembershipInvoicesJob < ApplicationJob
  queue_as :default

  def perform
    return unless Membership.enabled?

    Time.use_zone(Membership::TIME_ZONE) do
      expiring_invoices.find_each do |invoice|
        Membership::EnsureInvoice.call(membership: invoice.membership, covering: invoice.end_date + 1.day)
      end
    end
  end

  private

  def expiring_invoices
    MembershipInvoice
      .joins(:membership)
      .preload(:membership)
      .where(memberships: { cancelled_at: nil })
      .expiring_between(Date.current, Date.current + Membership::RENEWAL_WINDOW_DAYS)
  end
end
