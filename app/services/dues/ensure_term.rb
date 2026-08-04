module Dues
  class EnsureTerm
    def self.call(dues_membership:, covering: Date.current, cost_cents: nil)
      new(dues_membership:, covering:, cost_cents:).call
    end

    def initialize(dues_membership:, covering: Date.current, cost_cents: nil)
      @dues_membership = dues_membership
      @covering = covering
      @cost_cents = cost_cents
    end

    # Locked so a webhook and nightly job arriving together can't each create one.
    def call
      @dues_membership.with_lock do
        terms.active_on(@covering).first || create_term
      end
    end

    private

    def terms
      @dues_membership.dues_registrations
    end

    def create_term
      return if @dues_membership.cancelled?

      terms.create!(
        start_date: @covering,
        end_date: @covering + 1.year - 1.day,
        cost_cents: @cost_cents || @dues_membership.rate_cents || Dues::ANNUAL_COST_CENTS
      )
    end
  end
end
