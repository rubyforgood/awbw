class IssueMembershipInvoicesJob < ApplicationJob
  queue_as :default

  def perform
    return unless Membership.enabled?

    Time.use_zone(Membership::TIME_ZONE) do
      expiring_memberships.find_each do |membership|
        renew_membership(membership)
      end
    end
  end

  private

  def renew_membership(membership)
    Membership::Renew.call(membership: membership)
  rescue StandardError => e
    Rails.error.report(
      e,
      handled: true,
      source: "membership.issue_invoices",
      context: { membership_id: membership.id }
    )
  end

  def expiring_memberships
    Membership
      .unlocked
      .where(renewal_off_at: nil)
      .where(end_date: (Date.current - 1.day)..(Date.current + Membership.renewal_window_days))
      .includes(:membership_invoices)
  end
end
