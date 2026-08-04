class RenewDuesTermsJob < ApplicationJob
  queue_as :default

  def perform
    expiring_terms.find_each do |term|
      Dues::EnsureTerm.call(dues_membership: term.dues_membership, covering: term.end_date + 1.day)
    end
  end

  private

  def expiring_terms
    DuesRegistration
      .joins(:dues_membership)
      .preload(:dues_membership)
      .where(dues_memberships: { cancelled_at: nil })
      .expiring_between(Date.current, Date.current + Dues::RENEWAL_WINDOW_DAYS)
  end
end
