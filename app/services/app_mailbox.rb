# The app's contact mailboxes, read from deployment config rather than stored on an
# organization record: they are the app's own identity rather than one organization's
# attribute, and a sending address is bound to the domain's SPF/DKIM records, so a
# typo in an admin form would quietly cost deliverability.
class AppMailbox
  # The general contact address, shown on the contact page, the story-share footer,
  # and the invoice/receipt header.
  def self.info
    ENV["INFO_EMAIL"].presence || reply_to
  end

  def self.reply_to
    ENV["REPLY_TO_EMAIL"].presence
  end
end
