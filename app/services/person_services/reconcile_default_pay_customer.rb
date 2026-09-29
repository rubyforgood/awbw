module PersonServices
  # A merge can leave the survivor owning two live Pay customers, which makes Pay's
  # `payment_processor` (has_one default: true) ambiguous and lets a later checkout —
  # `set_payment_processor` clears every default, then re-picks `.first` active
  # customer — silently flip the default to the merged-in one.
  #
  # Settle it to a single winner and make the choice durable:
  #   * winner = the customer carrying an active subscription (so membership autopay,
  #     which reads `payment_processor.subscribed?` off the default customer, keeps
  #     working); failing that the survivor's own pre-merge default; failing that the
  #     newest. The preferred id is passed in because it must be read before the merge,
  #     while the survivor's own customer can still be told apart from the merged-in one.
  #   * every redundant same-processor sibling is soft-deleted so it drops out of the
  #     active scope and a future checkout can't re-pick it. Soft-delete sets
  #     `deleted_at` only — it does not trigger `dependent: :destroy`, so the customer's
  #     charges and subscriptions are preserved and stay queryable.
  #
  # A customer with an active subscription is never soft-deleted — hiding it would
  # strand a live billing relationship. A no-op unless more than one live customer remains.
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
      subscribed = live.select { |customer| active_subscription?(customer) }
      return subscribed.first if subscribed.one?

      candidates = subscribed.presence || live
      candidates.find { |customer| customer.id == @preferred_customer_id } ||
        candidates.max_by(&:created_at)
    end

    def redundant?(customer, winner)
      customer.processor == winner.processor &&
        customer.stripe_account == winner.stripe_account &&
        !active_subscription?(customer)
    end

    def active_subscription?(customer)
      customer.subscriptions.active_uncanceled.exists?
    end
  end
end
