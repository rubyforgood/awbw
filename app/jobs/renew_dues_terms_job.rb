class RenewDuesTermsJob < ApplicationJob
  queue_as :default

  def perform
    Time.use_zone(Dues::TIME_ZONE) do
      expiring_terms.find_each do |term|
        Dues::EnsureTerm.call(dues_subscription: term.dues_subscription, covering: term.end_date + 1.day)
      end
    end
  end

  private

  def expiring_terms
    DuesRegistration
      .joins(:dues_subscription)
      .preload(:dues_subscription)
      .where(dues_subscriptions: { cancelled_at: nil })
      .expiring_between(Date.current, Date.current + Dues::RENEWAL_WINDOW_DAYS)
  end
end
