class Membership::Start
  def self.call(person:)
    new(person:).call
  end

  def initialize(person:)
    @person = person
  end

  # Create the initial membership when a user is `invited`.
  # Skips anyone who already has one, cancelled or not.
  def call
    return unless Membership.enabled?
    return if @person.blank?
    return if @person.memberships.exists?

    membership = @person.memberships.create!
    Membership::EnsureInvoice.call(membership: membership, cost_cents: 0)
    membership
  end
end
