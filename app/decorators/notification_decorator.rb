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

  def title
    "Re #{noticeable_type} ##{noticeable_id}"
  end

  def detail(length: nil)
  end

  def channel_icon(**options)
    icon_class = CHANNEL_ICONS[channel]
    return "" if icon_class.blank?

    h.content_tag(:i, "", { class: "fa-solid #{icon_class} text-gray-400", title: channel.titleize, "aria-hidden": "true" }.merge(options))
  end
end
