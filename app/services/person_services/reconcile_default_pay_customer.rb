module PersonServices
  class ReconcileDefaultPayCustomer
    def initialize(person, preferred_customer_id:)
      @person = person
      @preferred_customer_id = preferred_customer_id
    end

    def call
      live = @person.pay_customers.active.to_a
      return if live.size <= 1

      winner = pick_winner(live)
      winner.update!(default: true) unless winner.default?

      live.each do |customer|
        next if customer == winner

        if redundant?(customer, winner)
          customer.update!(default: false, deleted_at: Time.current)
        elsif customer.default?
          customer.update!(default: false)
        end
      end
    end

    private

    def pick_winner(live)
      live.find { |customer| customer.id == @preferred_customer_id } ||
        live.max_by(&:created_at)
    end

    def redundant?(customer, winner)
      customer.processor == winner.processor &&
        customer.stripe_account == winner.stripe_account
    end
  end
end
