module PaySubscriptionExtensions
  extend ActiveSupport::Concern

  included do
    # Pay's `active` scope still counts a canceled subscription that's riding out its
    # grace period (status "active" with a scheduled `ends_at`). Narrow to the ones
    # that will actually keep billing: active and not scheduled to end.
    scope :active_uncanceled, -> { active.where(ends_at: nil) }
  end
end
