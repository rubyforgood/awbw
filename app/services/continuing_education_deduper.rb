# frozen_string_literal: true

# Consolidates a record's duplicate CE registrations after a merge: CE registrations
# that share an event registration and professional license are one enrollment, so
# they collapse to a single record. The losers' allocations (payments) and comments
# move onto the survivor, then the losers are destroyed.
class ContinuingEducationDeduper
  def initialize(registrations)
    @registrations = registrations
  end

  def call
    @registrations.group_by { |ce| [ ce.event_registration_id, ce.professional_license_id ] }
      .each_value { |group| collapse(group) if group.size > 1 }
  end

  private

  def collapse(group)
    survivor, *losers = group.sort_by { |ce| [ ce.certificate_sent_at ? 0 : 1, ce.created_at, ce.id ] }

    losers.each do |loser|
      Allocation.where(allocatable: loser).update_all(allocatable_id: survivor.id)
      Comment.where(commentable: loser).update_all(commentable_id: survivor.id)
      loser.reload.destroy!
    end

    # Keep the fuller hours and any certificate, and the real cost. When the merged-in
    # payments exceed that cost the survivor reads as over-allocated, flagged for an
    # admin (ContinuingEducationRegistration#over_allocated?); update_columns lets that
    # over-allocation persist past the cost_not_below_allocations validation.
    survivor.update_columns(
      hours: group.map(&:hours).max,
      cost_cents: group.map(&:cost_cents).max,
      certificate_sent_at: group.map(&:certificate_sent_at).compact.min
    )
  end
end
