module Dues
  class StartSubscription
    def self.call(person:)
      new(person:).call
    end

    def initialize(person:)
      @person = person
    end

    # Create initial subscription when user is `invited`
    # Skips anyone who already has a subscription, cancelled or not

    def call
      return if @person.blank?
      return if @person.dues_subscriptions.exists?

      subscription = @person.dues_subscriptions.create!
      EnsureTerm.call(dues_subscription: subscription, cost_cents: 0)
      subscription
    end
  end
end
