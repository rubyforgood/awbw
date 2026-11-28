# Makes a linked person's primary email their login email. The address it replaces moves
# to the secondary slot (swapping if that slot held the login email); when the secondary
# slot holds a third address, the replaced one is kept in an admin comment instead.
#
# When the login email itself changes, the old login address is dropped rather than kept:
# the primary email only mirrored it, and the auth.email_changed event records the change.
# A failed save leaves an admin comment so the stale email shows on the person's page.
class PersonLoginEmailSync
  def self.call(...)
    new(...).call
  end

  def initialize(user, previous_login_email: nil)
    @user = user
    @person = user.person
    @previous_login_email = previous_login_email
  end

  def call
    return true if @person.blank? || @user.email.blank?
    return true if @person.email.to_s.casecmp?(@user.email)

    replaced_email = @person.email.presence unless old_login?(@person.email)
    replaced_type = @person.email_type
    login_was_secondary = @person.email_2.to_s.casecmp?(@user.email)
    secondary_free = login_was_secondary || @person.email_2.blank?

    @person.email_type = @user.email_type.presence || (@person.email_2_type if login_was_secondary)
    @person.email = @user.email
    @person.assign_attributes(email_2: replaced_email, email_2_type: replaced_email && replaced_type) if secondary_free

    return report_failure unless @person.save

    note_replaced_email(replaced_email) if replaced_email && !secondary_free
    true
  end

  private

  def old_login?(address)
    @previous_login_email.present? && address.to_s.casecmp?(@previous_login_email)
  end

  def note_replaced_email(address)
    @person.comments.create_as_system!(
      topic: "Email replaced",
      body: "#{address} was the primary email until the login email #{@user.email} replaced it. " \
            "The secondary email already held #{@person.email_2}, so it is recorded here."
    )
  end

  def report_failure
    Rails.error.report(
      ActiveRecord::RecordInvalid.new(@person),
      handled: true,
      context: { user_id: @user.id, person_id: @person.id }
    )
    errors = @person.errors.full_messages.to_sentence
    @person.restore_attributes
    note_failure(errors)
    false
  end

  def note_failure(errors)
    @person.comments.create_as_system!(
      topic: "Login email not copied",
      body: "The login email #{@user.email} couldn't become the primary email: #{errors}. " \
            "If another person already has this name and email, merging the two at the dedupe page fixes it."
    )
  end
end
