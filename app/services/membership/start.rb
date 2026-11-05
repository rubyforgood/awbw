class Membership::Start
  def self.call(person:)
    new(person:).call
  end

  def initialize(person:)
    @person = person
  end

  def call
    return unless Membership.enabled?
    return if @person.blank?
    return if @person.memberships.exists?

    Time.use_zone(Membership::TIME_ZONE) do
      Membership::Create.call(
        person: @person,
        start_date: Date.current,
        invoice_cost_cents: 0
      ).membership
    end
  end
end
