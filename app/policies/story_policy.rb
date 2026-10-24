class StoryPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  def index?
    true
  end

  def show?
    return true if admin? || own_story?
    return false if record.funder_only?
    record.publicly_visible? || (authenticated? && record.published?)
  end

  # Bulk import from a WordPress export CSV — admins only.
  def import?
    admin?
  end

  def search?
    authenticated?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping
  #
  relation_scope do |relation|
    next relation if admin?
    viewable(relation)
  end

  # The stories listed on a person's profile. The person and admins see every credit;
  # everyone else sees only viewable stories, minus credits the person made anonymous.
  relation_scope(:on_profile) do |relation, person:|
    next profile_credits(relation, person, openly: false) if admin? || user&.person_id == person.id
    profile_credits(viewable(relation), person, openly: true)
  end

  private

  def viewable(relation)
    scope = relation.not_funder_only
    authenticated? ? scope.published : scope.publicly_visible
  end

  # A spotlight is not an author credit, so anonymity never hides it.
  def profile_credits(relation, person, openly:)
    spotlighted = relation.where(spotlighted_facilitator_id: person.id)
    return spotlighted if openly && person.anonymous_contributions?

    authored = relation.where(author_id: person.id)
      .or(relation.where(author_id: nil, created_by_id: User.where(person_id: person.id).select(:id)))
    co_authored = relation.where(co_author_id: person.id)
    if openly
      authored = authored.credited_openly
      co_authored = co_authored.co_credited_openly
    end
    spotlighted.or(authored).or(co_authored)
  end

  # The named author, a credited co-author, or the submitter — the people who
  # may see their own story even when it's funder-only.
  def own_story?
    return false unless user
    person_id = user.person_id
    (person_id.present? && [ record.author_id, record.co_author_id ].include?(person_id)) ||
      record.created_by_id == user.id
  end
end
