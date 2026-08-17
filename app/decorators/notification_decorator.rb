class NotificationDecorator < ApplicationDecorator
  # Solid Font Awesome icon per communication channel, shown before the subject
  # in the communications box. "autoemail" (system email) reuses the envelope;
  # "text" uses a mobile handset to stay distinct from the "phone" call icon.
  CHANNEL_ICONS = {
    "autoemail" => "fa-envelope",
    "email" => "fa-envelope",
    "phone" => "fa-phone",
    "text" => "fa-mobile-screen-button",
    "video" => "fa-video"
  }.freeze

  # Shown as the "From" on a communication that no staff member sent by hand.
  PORTAL_SENDER_NAME = "AWBW Portal".freeze

  # At-a-glance audience pill for the compact row/index and detail page — only
  # the two exceptions are flagged: sky for an incoming message (the person wrote
  # to us) and a neutral grey "FYI" for an admin copy (recipient_role "admin").
  # A regular message to the person is the norm and shows no pill.
  AUDIENCE_META = {
    "incoming" => { label: "Incoming", classes: "bg-sky-100 text-sky-800" },
    "fyi" => { label: "FYI", classes: "bg-gray-100 text-gray-700" }
  }.freeze

  # Additional "Bulk" pill for a communication sent as part of a bulk operation
  # (the bulk_payment_* kinds), whether the copy to the person or the admin FYI.
  BULK_META = { label: "Bulk", classes: "bg-indigo-100 text-indigo-800" }.freeze

  def sender_name
    sender&.full_name.presence || PORTAL_SENDER_NAME
  end

  # The person on the non-staff side of the communication, resolved from
  # recipient_email so we can show their name and reveal the email on hover.
  # Matches a person's primary or secondary email; memoized. One lookup per row —
  # fine for the paginated admin index; revisit if it ever renders unpaginated.
  def contact_person
    return @contact_person if defined?(@contact_person)

    @contact_person = if recipient_email.present?
      Person.where(email: recipient_email).or(Person.where(email_2: recipient_email)).first
    end
  end

  # Name of the person when we know them, otherwise the raw email.
  def contact_name
    contact_person&.name.presence || recipient_email
  end

  # Email to reveal on hover — only when we're showing a resolved name (nil when
  # the displayed value is already the raw email).
  def contact_hover
    recipient_email if contact_person
  end

  # From/To flip with direction. An outgoing communication is sent by staff (or
  # the portal) to the person, so From is the sender and To is the person. An
  # incoming one was sent *by* the person, so the person is From and the staff
  # member who logged it (the sender) is To. The person side shows their name
  # (with the email on the matching *_title hover) when we have them on file.
  def from_name
    incoming? ? contact_name : sender_name
  end

  def to_name
    incoming? ? sender_name : contact_name
  end

  def from_title
    incoming? ? contact_hover : nil
  end

  def to_title
    incoming? ? nil : contact_hover
  end

  # The contact Person sits on the To side of an outgoing communication and the
  # From side of an incoming one; the opposite side is staff or the AWBW Portal,
  # which has no person to link to. nil when the contact isn't on file either.
  def to_person
    contact_person unless incoming?
  end

  def from_person
    contact_person if incoming?
  end

  # The contact's email for each side, mirroring to_person/from_person — always
  # recipient_email, on whichever side the contact sits. nil on the staff/portal
  # side, which is a person's name (or "AWBW Portal"), not an address.
  def to_email
    recipient_email unless incoming?
  end

  def from_email
    recipient_email if incoming?
  end

  # People-column value for the index: the name linked to the person's profile
  # when we've resolved them, a mailto link when we only have their email, plain
  # text otherwise. The AWBW Portal (and any staff name) has no address, so it
  # renders unlinked.
  def to_value
    people_value(to_name, to_person, to_email, to_title)
  end

  def from_value
    people_value(from_name, from_person, from_email, from_title)
  end

  # "incoming" (the person wrote to us), "fyi" (an admin FYI copy), or nil for a
  # regular message to the person (the norm — no pill). Drives the audience pill.
  def audience
    return "incoming" if incoming?

    "fyi" if recipient_role == "admin"
  end

  def audience_badge(**options)
    pill(AUDIENCE_META[audience], **options)
  end

  # Part of a bulk send, so the index can flag it with a "Bulk" pill. Two things
  # count: the bulk_payment_* kinds (unambiguous from the kind alone), and any
  # send explicitly marked via the `bulk` column — bulk reminders and invites,
  # whose kind is shared with one-off sends.
  def bulk?
    object.bulk? || kind.to_s.start_with?("bulk_")
  end

  # Every applicable flag pill for this communication, rendered together:
  # the audience (Incoming/FYI) plus Bulk when part of a bulk send. Empty for a
  # plain message to the person.
  def flag_badges(**options)
    metas = [ AUDIENCE_META[audience], (BULK_META if bulk?) ].compact
    return "" if metas.empty?

    h.safe_join(metas.map { |meta| pill(meta, **options) }, " ")
  end

  def title
    return "Re #{noticeable_type} ##{noticeable_id}" if noticeable_type.present?

    # The subject record was deleted (nullified) — fall back to the recipient so
    # an orphaned communication still reads as a real message, not "Re  #".
    "Re #{object.recipient_email}"
  end

  def detail(length: nil)
  end

  # Whole-row tint on the communications index: red error for a failed send,
  # amber warning for one stuck pending past the grace period, default hover
  # otherwise (delivered, or still within the fresh-send window).
  def row_class
    return "bg-red-50 hover:bg-red-100" if failed?
    return "bg-amber-50 hover:bg-amber-100" if stuck_pending?

    "hover:bg-gray-50"
  end

  # Detail-page card background: red error for a failed send, amber warning for
  # one stuck pending past the grace period, the notifications domain colour
  # otherwise (delivered, or still within the fresh-send window).
  def card_bg_class
    return "bg-red-50 border-red-300" if failed?
    return "bg-amber-50 border-amber-300" if stuck_pending?

    "#{DomainTheme.bg_class_for(:notifications)} border-gray-200"
  end

  def channel_icon(**options)
    icon_class = CHANNEL_ICONS[channel]
    return "" if icon_class.blank?

    h.content_tag(:i, "", { class: "fa-solid #{icon_class} text-gray-400", title: channel.titleize, "aria-hidden": "true" }.merge(options))
  end

  private

  # Links the value to the person's profile when we have one, to a mailto when we
  # only have their email, otherwise a plain span. The profile link keeps the
  # email available on hover (title).
  def people_value(name, person, email, title)
    return h.link_to(name, h.person_path(person), title: title, data: { turbo_frame: "_top" }, class: "hover:underline") if person
    return h.mail_to(email, name, class: "hover:underline") if email.present?

    h.content_tag(:span, name, title: title)
  end

  # Renders a coloured label pill from a *_META entry. Returns "" for a nil
  # entry. A caller-supplied `class:` is appended to the pill's own styling
  # rather than replacing it.
  def pill(meta, **options)
    return "" unless meta

    extra_class = options.delete(:class)
    classes = [ "inline-flex items-center rounded px-1.5 py-0.5 text-xs font-medium", meta[:classes], extra_class ].compact.join(" ")
    h.content_tag(:span, meta[:label], { class: classes }.merge(options))
  end
end
