module PersonServices
  # A merge can leave the survivor owning two live Pay customers both flagged
  # default, which makes Pay's `payment_processor` (has_one default: true) ambiguous.
  # Settle it to a single default: the survivor's own pre-merge default, or — when it
  # had none — whichever moved default is newest. The preferred id is passed in
  # because it must be read before the merge, while the survivor's own customer can
  # still be told apart from the merged-in one. A no-op unless more than one remains.
  class ReconcileDefaultPayCustomer
    def initialize(person, preferred_customer_id:)
      @person = person
      @preferred_customer_id = preferred_customer_id
    end

    def call
      defaults = @person.pay_customers.active.where(default: true).to_a
      return if defaults.size <= 1

      winner = defaults.find { |customer| customer.id == @preferred_customer_id } ||
        defaults.max_by(&:created_at)

      defaults.each do |customer|
        customer.update!(default: false) unless customer == winner
      end
    end
  end
end
