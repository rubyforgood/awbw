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

  Milestone = Data.define(:label, :date, :detail, :state)

  ACCOUNT_MILESTONES = [
    [ "Created", "Created", :created_at ],
    [ "Invited", "Invited", :welcome_instructions_sent_at ],
    [ "Confirmed", "Confirmed", :confirmed_at ],
    [ "Current login", "Logged in", :latest_sign_in_at ]
  ].freeze

  MILESTONE_TEXT_CLASSES = {
    reached: "text-gray-700",
    next: "text-amber-700",
    pending: "text-gray-400",
    locked: "text-red-700",
    inactive: "text-gray-500"
  }.freeze

  # A later step implies the earlier ones, so legacy logins missing an invite date still read as complete.
  def account_milestones
    dates = ACCOUNT_MILESTONES.map { |_, _, attribute| public_send(attribute) }
    reached = dates.each_index.map { |index| dates.drop(index).any?(&:present?) }
    next_index = reached.index(false) unless account_stop

    ACCOUNT_MILESTONES.each_with_index.map do |(reached_label, pending_label, _), index|
      state = if reached[index] then :reached elsif index == next_index then :next else :pending end
      Milestone.new(label: reached[index] ? reached_label : pending_label, date: short_date(dates[index]), detail: nil, state:)
    end
  end

  def account_stop
    return Milestone.new(label: "Inactive", date: nil, detail: "By staff", state: :inactive) if inactive?
    return unless locked_at

    Milestone.new(label: "Locked", date: short_date(locked_at), detail: lock_reason, state: :locked)
  end

  def admin_badge(extra: nil)
    h.render "shared/badge", label: "Admin", icon: "fa-solid fa-user-shield",
             classes: "bg-blue-50 text-blue-700 border-blue-200", extra:
  end

  def milestone_text_classes(milestone)
    MILESTONE_TEXT_CLASSES.fetch(milestone.state)
  end

  def latest_sign_in_at
    current_sign_in_at || last_sign_in_at
  end

  def password_reset_pending?
    reset_password_token.present? && reset_password_sent_at&.after?(Devise.reset_password_within.ago)
  end

  def password_reset_label
    "Password reset sent #{short_date(reset_password_sent_at)}"
  end

  def display_primary_address
    primary_address == 1 ? "work" : "home"
  end

  private

  def lock_reason
    return "By staff" if failed_attempts < Devise.maximum_attempts

    "#{failed_attempts} failed logins"
  end

  def short_date(time)
    time&.strftime("%b %-d, %Y")
  end
end
