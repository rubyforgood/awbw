module Dues
  class StartSubscription
    def self.call(person:)
      new(person:).call
    end

    def initialize(person:)
      @person = person
    end

    # Skips anyone who already has a subscription, cancelled or not: re-inviting must
    # not hand out a second free year, and bringing a cancelled member back is an
    # admin clearing `cancelled_at`, which keeps their original rate.
    def call
      return if @person.blank?
      return if @person.dues_subscriptions.exists?

      subscription = @person.dues_subscriptions.create!
      EnsureTerm.call(dues_subscription: subscription, cost_cents: 0)
      subscription
    end
  end
end
