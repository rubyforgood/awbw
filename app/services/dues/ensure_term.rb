module Dues
  class EnsureTerm
    def self.call(dues_subscription:, covering: Date.current, cost_cents: nil)
      new(dues_subscription:, covering:, cost_cents:).call
    end

    def initialize(dues_subscription:, covering: Date.current, cost_cents: nil)
      @dues_subscription = dues_subscription
      @covering = covering
      @cost_cents = cost_cents
    end

    # Locked so a webhook and nightly job arriving together can't each create one.
    def call
      @dues_subscription.with_lock do
        terms.active_on(@covering).first || create_term
      end
    end

    private

    def terms
      @dues_subscription.dues_registrations
    end

    def create_term
      return if @dues_subscription.cancelled?

      terms.create!(
        start_date: @covering,
        end_date: @covering + 1.year - 1.day,
        cost_cents: @cost_cents || @dues_subscription.rate_cents || Dues::ANNUAL_COST_CENTS
      )
    end
  end
end
