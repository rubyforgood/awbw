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
      survivor.hours = [ survivor.hours, loser.hours ].max
      survivor.cost_cents = [ survivor.cost_cents, loser.cost_cents ].max
      survivor.certificate_sent_at ||= loser.certificate_sent_at
      loser.reload.destroy!
    end

    survivor.cost_cents = [ survivor.cost_cents, survivor.allocations.sum(:amount) ].max
    survivor.save!
  end
end
