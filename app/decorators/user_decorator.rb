class UserDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: nil) # arg needed for idea_submission_fyi mailer
    email
  end

  def default_display_image
    return person.avatar if person&.avatar&.attached?
    "missing.png"
  end

  # Two-letter stamp for the author chip on a comment row — the linked person's
  # first/last initials, falling back to the account name's words.
  def initials
    return "#{person.first_name.to_s.first}#{person.last_name.to_s.first}".upcase if person

    name.to_s.split.map(&:first).join.upcase.presence
  end

  def full_name
    return unless user
    if first_name.empty?
      email
    else
      "#{first_name} #{last_name}"
    end
  end

  # Why this login can't sign in — empty when it can.
  def access_statuses
    [ ("Inactive" if inactive?), ("Locked" if locked_at.present?), ("Unconfirmed" if confirmed_at.nil?) ].compact
  end

  def search_label_with_status
    { id: id, label: [ full_name_with_email, access_statuses.join(", ").presence ].compact.join(" · ") }
  end

  def last_logged_in
    return "never" unless last_sign_in_at
    "#{h.time_ago_in_words(last_sign_in_at)} ago"
  end

  def last_login_label
    return "Never logged in" unless last_sign_in_at

    "Last logged in #{last_sign_in_at.strftime("%b %-d, %Y")}"
  end

  def invited_label
    "Invited #{welcome_instructions_sent_at.strftime("%b %-d, %Y")}" if welcome_instructions_sent_at
  end

  def display_primary_address
    primary_address == 1 ? "work" : "home"
  end
end
