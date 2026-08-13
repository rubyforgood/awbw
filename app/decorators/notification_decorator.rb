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

  def sender_name
    sender&.full_name.presence || PORTAL_SENDER_NAME
  end

  def title
    "Re #{noticeable_type} ##{noticeable_id}"
  end

  def detail(length: nil)
  end

  # Whole-row tint on the communications index: red error for a failed send,
  # amber warning for one still pending, default hover once delivered.
  def row_class
    return "hover:bg-gray-50" if delivered?

    failed? ? "bg-red-50 hover:bg-red-100" : "bg-amber-50 hover:bg-amber-100"
  end

  # Detail-page card background: red error for a failed send, amber warning for
  # one still pending, the notifications domain colour once delivered.
  def card_bg_class
    return "#{DomainTheme.bg_class_for(:notifications)} border-gray-200" if delivered?

    failed? ? "bg-red-50 border-red-300" : "bg-amber-50 border-amber-300"
  end

  def channel_icon(**options)
    icon_class = CHANNEL_ICONS[channel]
    return "" if icon_class.blank?

    h.content_tag(:i, "", { class: "fa-solid #{icon_class} text-gray-400", title: channel.titleize, "aria-hidden": "true" }.merge(options))
  end
end
