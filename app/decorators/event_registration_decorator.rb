class EventRegistrationDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: nil)
  end

  def link_target
    h.registration_ticket_path(slug)
  end

  # Human-readable explanation of why the Delete button is unavailable, or nil
  # when the registration is deletable. Reverted payments still leave allocation
  # rows, so they count here even though they net to zero — hence the aside.
  def deletion_blocked_reason
    return if deletable?

    reasons = []
    reasons << "payment or scholarship records (reverted payments still count)" if allocations.exists?
    reasons << "attendance on record" if attendance_recorded?
    "Can't be deleted — this registration has #{reasons.to_sentence}."
  end

  def default_display_image
    return event.primary_asset.file if event.respond_to?(:primary_asset) && event.primary_asset&.file&.attached?
    "theme_default.png"
  end
end
