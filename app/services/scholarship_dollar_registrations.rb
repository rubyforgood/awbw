# Which registration a scholarship's dollars count toward. An award's record stays
# on the registration it was issued on, but once that registration transfers, its
# dollars count at the training transferred into — unless that registration no
# longer holds money (cancelled / no-show), which leaves them at the original.
class ScholarshipDollarRegistrations
  # registration_ids: the registrations a report counts dollars for, or award
  # registrations to re-key with #counting_registration_id.
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
  # registrations whose destination still holds money.
  def moved_destination_by_origin
    @moved_destination_by_origin ||= begin
      return {} if @registration_ids.empty?

      ids = @registration_ids.to_a
      EventRegistration.holding_money
        .where(transferred_from_registration_id: ids)
        .or(EventRegistration.holding_money.where(id: ids).where.not(transferred_from_registration_id: nil))
        .pluck(:transferred_from_registration_id, :id)
        .to_h
    end
  end
end
