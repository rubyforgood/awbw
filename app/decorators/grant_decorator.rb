class GrantDecorator < ApplicationDecorator
  # Title/detail back the shared taggings card (app/views/taggings/_tagged_item_card).
  def title
    object.name
  end

  def detail(length: nil)
    text = object.description
    length ? text&.truncate(length) : text
  end

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

  # Compact deadline for the index — abbreviated month and day (e.g. "Aug 17"),
  # with the full date (year included) on hover. Dropping the year from the cell
  # keeps the column narrow so the grant-name column gets more width.
  def funds_allocation_deadline_compact
    date = object.funds_allocation_deadline
    return "—" unless date

    h.tag.span(date.strftime("%b %-d"), title: date.strftime("%B %-d, %Y"), class: "cursor-help")
  end

  def funds_received_on
    object.funds_received_on&.strftime("%B %-d, %Y") || "—"
  end

  def fully_allocated?
    object.remaining_cents <= 0
  end

  # Amber pill flagging a grant as a Legacy Circle scholarship (funded through planned
  # giving). Renders nothing for ordinary grants, so callers can inline it.
  def legacy_scholarship_badge
    return unless object.planned_giving?

    h.tag.span("Legacy",
               class: "inline-flex items-center rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800",
               title: "Legacy Circle scholarship — funded through planned giving")
  end

  # Rose pill flagging a legacy scholarship given in memory of a loved one — a
  # Healing HeARTs Legacy Circle: In Memoriam gift. Renders alongside the legacy
  # scholarship badge; nothing for ordinary grants.
  def in_memoriam_badge
    return unless object.in_memoriam?

    h.tag.span("Memoriam",
               class: "inline-flex items-center rounded-full bg-rose-100 px-2 py-0.5 text-xs font-medium text-rose-800",
               title: "Legacy Circle in memoriam — given in memory of a loved one")
  end

  # Whole-number percentage of the grant awarded in scholarships, clamped to
  # 0–100, for rendering the allocation progress bar on the index.
  def allocation_percentage
    return 0 if object.amount_cents.to_i.zero?

    ((object.scholarships_total_cents.to_d / object.amount_cents) * 100).clamp(0, 100).round
  end

  # Whole-number percentage of the grant still unallocated, for the "Remaining"
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

  # Short human-readable total funding amount for the grant picker, e.g. "$10k".
  def amount_compact
    MoneyFormatter.compact_from_cents(object.amount_cents)
  end

  # Plain-text remaining-of-total summary (e.g. "$750 of $12.5k available"),
  # used as the picker pill's accessible title/tooltip.
  def funds_remaining_summary
    "#{remaining_compact} of #{amount_compact} available"
  end
end
