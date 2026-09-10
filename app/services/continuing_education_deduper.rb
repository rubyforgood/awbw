# frozen_string_literal: true

# Collapses duplicate CE registrations that a merge left sharing one parent. Two
# duplicate people (or event registrations) each carry their own CE registration;
# once merged they land on the same event registration and license, so the person
# now holds two CE records for a single enrollment. CE has no DB unique index, so
# ModelDeduper never compares CE rows and just moves them all onto the keeper. We
# consolidate them here instead: same event registration + license is one CE record,
# and the losers' allocations (payments) and comments move onto the survivor before
# the losers are destroyed.
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

    # Keep the fuller hours and any certificate, but leave cost at the real figure
    # rather than inventing one to cover the combined payments — if the merged
    # payments now exceed it, ContinuingEducationRegistration#over_allocated? flags
    # it for an admin. update_columns so that allowed over-allocation persists past
    # the cost_not_below_allocations validation.
    survivor.update_columns(
      hours: group.map(&:hours).max,
      cost_cents: group.map(&:cost_cents).max,
      certificate_sent_at: group.map(&:certificate_sent_at).compact.min
    )
  end
end
