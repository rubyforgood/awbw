class GrantDecorator < ApplicationDecorator
  def amount
    h.dollars_from_cents(object.amount_cents)
  end

  def allocated
    h.dollars_from_cents(object.scholarships_total_cents)
  end

  def remaining
    h.dollars_from_cents(object.remaining_cents)
  end

  def funds_allocation_deadline
    object.funds_allocation_deadline&.strftime("%B %-d, %Y") || "—"
  end

  def funds_received_on
    object.funds_received_on&.strftime("%B %-d, %Y") || "—"
  end

  def fully_allocated?
    object.remaining_cents <= 0
  end

  # Whole-number percentage of the donation awarded in scholarships, clamped to
  # 0–100, for rendering the allocation progress bar on the index.
  def allocation_percentage
    return 0 if object.amount_cents.to_i.zero?

    ((object.scholarships_total_cents.to_d / object.amount_cents) * 100).clamp(0, 100).round
  end

  # Whole-number percentage of the donation still unallocated, for the "Remaining"
  # bar on the index — full green when untouched, empty (grey track) when spent.
  def remaining_percentage
    100 - allocation_percentage
  end

  # Scholarship counts for the index "Scholarships" column, shown as
  # completed/total. .size / Enumerable count use the preloaded association
  # (index eager-loads :scholarships) so these add no per-row queries.
  def scholarships_count
    object.scholarships.size
  end

  def completed_scholarships_count
    object.scholarships.count(&:tasks_completed?)
  end

  # Where the index "Scholarships" count links. When every event-funded
  # scholarship is for a single event, point at that event's registrants index
  # filtered to these recipients. A grant can span events (or be grant-funded
  # with no event), so fall back to the grant page, which lists them all.
  def scholarships_link
    registrations = object.scholarships.filter_map(&:allocation).map(&:allocatable).grep(EventRegistration)
    events = registrations.map(&:event).uniq
    return h.grant_path(object) unless events.one?

    recipient_ids = registrations.map(&:registrant_id).uniq.join("-")
    h.registrants_event_path(events.first, registrant_ids: recipient_ids)
  end

  # Short human-readable remaining balance for the grant picker, e.g. "$750" or
  # "$12.5k". The picker bolds this as the figure that matters most.
  def remaining_compact
    MoneyFormatter.compact_from_cents(object.remaining_cents)
  end

  # Short human-readable total donation for the grant picker, e.g. "$10k".
  def amount_compact
    MoneyFormatter.compact_from_cents(object.amount_cents)
  end

  # Plain-text remaining-of-total summary (e.g. "$750 of $12.5k available"),
  # used as the picker pill's accessible title/tooltip.
  def funds_remaining_summary
    "#{remaining_compact} of #{amount_compact} available"
  end
end
