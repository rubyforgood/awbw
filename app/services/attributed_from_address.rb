class AttributedFromAddress
  # Builds the From header for mail an admin sends by hand. SendGrid only authorizes
  # our own domain, so the address stays generic and only the display name names the
  # sender — "Dana Sender <programs@awbw.org>". Returns the address untouched when
  # there's no sender, so automated mail keeps going out as the portal.
  def self.call(sender, address)
    return address if address.blank?

    name = sender&.full_name.to_s.gsub(/[[:cntrl:]]/, " ").squish.presence
    return address unless name

    Mail::Address.new(address).tap { |a| a.display_name = name }.format
  end
end
