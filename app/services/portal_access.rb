# Whether a user's relationships with AWBW still entitle them to sign in (ADR-0006).
# A person is lapsed when they hold a membership or facilitator affiliation but
# none of them is current; people with neither on record aren't gated.
class PortalAccess
  # SQL twin of #lapsed?'s relationship test, kept in lock-step by an agreement spec.
  def self.lapsed_people
    facilitator_affiliations = Affiliation.facilitators
    held = Person.where(id: facilitator_affiliations.select(:person_id))
    current = Person.where(id: facilitator_affiliations.with_status(Affiliation::ACTIVE_OR_UPCOMING).select(:person_id))
    if Membership.enabled?
      held = held.or(Person.where(id: Membership.select(:person_id)))
      current = current.or(Person.where(id: Membership.not_cancelled.select(:person_id)))
    end
    held.where.not(id: current.select(:id))
  end

  def initialize(user)
    @user = user
  end

  def lapsed?
    return false if @user.super_user? || @user.person.nil?

    held = facilitator_affiliations + memberships
    current = facilitator_affiliations.reject(&:inactive_on?) + memberships.reject(&:cancelled?)
    held.any? && current.none?
  end

  private

  def facilitator_affiliations
    @facilitator_affiliations ||= @user.person.affiliations.select(&:facilitator?)
  end

  def memberships
    @memberships ||= Membership.enabled? ? @user.person.memberships.to_a : []
  end
end
