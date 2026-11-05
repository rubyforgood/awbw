# What each registration still owes, loaded in bulk for the money reports. A
# transfer keeps one balance: a transferred-in reg is priced at the event it was
# first bought for, and money on every reg along the way settles it.
class RegistrationBalances
  def initialize(registration_ids)
    @registration_ids = registration_ids
  end

  # { registration_id => cents owed, floored at zero }. Ids not passed in read as 0.
  def due_cents_by_id
    @due_cents_by_id ||= @registration_ids.each_with_object(Hash.new(0)) do |id, map|
      chain = transfer_chain(id)
      allocated = chain.sum { |chain_id| allocated_by_id.fetch(chain_id, 0) }
      map[id] = [ registrations_by_id[chain.last].cost_cents - allocated, 0 ].max
    end
  end

  private

  Registration = Struct.new(:source_id, :cost_cents, keyword_init: true)

  # The reg and every reg it was transferred from, oldest last.
  def transfer_chain(id)
    chain = [ id ]
    while (source_id = registrations_by_id[chain.last].source_id)
      chain << source_id
    end
    chain
  end

  # One query per transfer hop, so the count doesn't grow with the number of regs.
  def registrations_by_id
    @registrations_by_id ||= {}.tap do |map|
      ids = @registration_ids
      while ids.any?
        rows = EventRegistration.joins(:event).where(id: ids)
          .pluck(:id, :transferred_from_registration_id, "events.cost_cents")
        rows.each { |id, source_id, cost| map[id] = Registration.new(source_id: source_id, cost_cents: cost.to_i) }
        ids = rows.filter_map { |_id, source_id, _cost| source_id } - map.keys
      end
    end
  end

  def allocated_by_id
    @allocated_by_id ||= Allocation
      .where(allocatable_type: "EventRegistration", allocatable_id: registrations_by_id.keys)
      .group(:allocatable_id)
      .sum(:amount)
  end
end
