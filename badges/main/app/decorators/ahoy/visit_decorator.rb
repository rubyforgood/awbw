module Ahoy
  class VisitDecorator < ApplicationDecorator
    # Friendly names for DeviceDetector's device types (dev-speak → plain English).
    DEVICE_LABELS = {
      "smartphone" => "Mobile",
      "phablet" => "Mobile",
      "tablet" => "Tablet",
      "desktop" => "Desktop",
      "console" => "Console",
      "tv" => "TV",
      "smart display" => "Smart display",
      "car browser" => "Car",
      "camera" => "Camera",
      "portable media player" => "Media player",
      "wearable" => "Wearable"
    }.freeze
    private_constant :DEVICE_LABELS

    # A short, non-technical summary of the visit for the visits table, device
    # first, e.g. "Desktop · Windows 10 · Firefox 5.0". The raw user agent is on hover.
    def user_agent_summary
      return "Unknown" if object.user_agent.blank?

      [ device_label, os_detail, browser_detail ].compact.join(" · ").presence || "Unknown"
    end

    # The raw user agent, shown on hover for admins who need the full string.
    def user_agent_details
      object.user_agent.to_s
    end

    private

    def browser_detail
      return nil if detector.name.blank?

      [ detector.name, detector.full_version ].compact.join(" ")
    end

    def os_detail
      return nil if detector.os_name.blank?

      [ detector.os_name, detector.os_full_version ].compact.join(" ")
    end

    def device_label
      DEVICE_LABELS[detector.device_type]
    end

    def detector
      @detector ||= DeviceDetector.new(object.user_agent.to_s)
    end
  end
end
