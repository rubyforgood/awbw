# Which registration a scholarship's dollars count toward. An award stays on the
# registration it was issued on, but when that registration transferred to an
# earlier training, its dollars count there instead; a transfer to a later (or
# same-day or undated) training leaves them at the original.
class ScholarshipDollarRegistrations
  # registration_ids: the registrations a report counts dollars for.
  def initialize(registration_ids)
    @registration_ids = registration_ids.to_set
  end

  # Registrations whose awards count toward the given ones — query allocations by
  # these, then re-key each award with #counting_registration_id.
  def award_registration_ids
    @award_registration_ids ||= (@registration_ids.to_a + moved_destination_by_origin.keys)
      .uniq
      .select { |id| @registration_ids.include?(counting_registration_id(id)) }
  end

  def counting_registration_id(award_registration_id)
    moved_destination_by_origin.fetch(award_registration_id, award_registration_id)
  end

  private

  # { origin registration id => destination id } for transfers touching these
  # registrations whose destination is an earlier training it still holds money on.
  def moved_destination_by_origin
    @moved_destination_by_origin ||= find_moved_destinations
  end

  def find_moved_destinations
    pairs = transfer_rows.select { |_destination_id, _origin_id, status, _start| status.in?(EventRegistration::MONEY_STATUSES) }
    return {} if pairs.empty?

    origin_start_by_id = EventRegistration.joins(:event).where(id: pairs.map(&:second)).pluck(:id, "events.start_date").to_h
    pairs.each_with_object({}) do |(destination_id, origin_id, _status, destination_start), map|
      origin_start = origin_start_by_id[origin_id]
      next unless destination_start && origin_start
      map[origin_id] = destination_id if destination_start.to_date < origin_start.to_date
    end
  end

  # [ [ destination id, origin id, destination status, destination start ], ... ]
  def transfer_rows
    return [] if @registration_ids.empty?

    ids = @registration_ids.to_a
    EventRegistration.joins(:event)
      .where(transferred_from_registration_id: ids)
      .or(EventRegistration.joins(:event).where(id: ids).where.not(transferred_from_registration_id: nil))
      .pluck(:id, :transferred_from_registration_id, :status, "events.start_date")
  end
end
