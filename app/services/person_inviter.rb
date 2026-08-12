# Invites a single person to the portal: creates a portal user for them when they
# don't have one yet, then sends the welcome/invite email (Devise confirmation
# instructions), attributing it to the staff member who triggered it. Drives the
# bulk "Send Portal invite emails" flow on the reminders page, and mirrors the create-user
# + send-invite steps in EventRegistrationServices::ProcessConfirmation.
class PersonInviter
  Result = Struct.new(:invited, :reason, keyword_init: true)

  def self.call(person:, sender: nil)
    new(person: person, sender: sender).call
  end

  def initialize(person:, sender: nil)
    @person = person
    @sender = sender
  end

  def call
    email = @person.preferred_email
    return Result.new(invited: false, reason: :no_email) if email.blank?

    user = @person.user || create_user(email)
    return Result.new(invited: false, reason: :no_user) unless user
    return Result.new(invited: false, reason: :already_confirmed) if user.confirmed_at.present?

    send_invite(user)
    Result.new(invited: true, reason: nil)
  end

  private

  def create_user(email)
    password = SecureRandom.hex(8)
    user = User.new(
      email: email,
      password: password,
      password_confirmation: password,
      person: @person,
      created_by: @sender,
      updated_by: @sender
    )
    user.skip_confirmation_notification!
    return unless user.save

    @person.reload
    @person.user
  end

  def send_invite(user)
    user.updated_by = @sender
    user.set_welcome_instructions_token!
    user.update!(welcome_instructions_sent_at: Time.current, welcome_instructions_sent_by: @sender)
    user.send_confirmation_instructions(sender: @sender)
  end
end
