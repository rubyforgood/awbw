# Makes a linked person's primary email their login email. The address it replaces moves
# to the secondary slot (swapping if that slot held the login email); when the secondary
# slot holds a third address, the replaced one is kept in an admin comment instead.
class PersonLoginEmailSync
  def self.call(...)
    new(...).call
  end

  def initialize(user)
    @user = user
    @person = user.person
  end

  def call
    return true if @person.blank? || @user.email.blank?
    return true if @person.email.to_s.casecmp?(@user.email)

    replaced_email = @person.email.presence
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

  def note_replaced_email(address)
    @person.comments.create!(
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
    @person.restore_attributes
    false
  end
end
