# Collects every comment "related" to a commentable, where the meaning of
# related depends on the commentable's type. The type is the signal of which
# comment box the user opened the overview from (each box links to its own
# polymorphic comments path), so this is the single place that decides what
# context to surface for each kind of record.
class RelatedComments
  def initialize(commentable)
    @commentable = commentable
  end

  def comments
    commentable_groups
      .map { |type, ids| Comment.where(commentable_type: type, commentable_id: ids) }
      .reduce(:or)
      .includes(:commentable, created_by: :person, updated_by: :person)
      .newest_first
  end

  private

  def commentable_groups
    ([ @commentable ] + related_records).compact.uniq
      .group_by { |record| record.class.base_class.name }
      .transform_values { |records| records.map(&:id).uniq }
  end

  def related_records
    case @commentable
    when EventRegistration then registration_related
    when Person then person_related
    when Organization then organization_related
    when User then user_related
    when Workshop then workshop_related
    else []
    end
  end

  def registration_related
    person = @commentable.registrant
    return [] unless person

    [ person, person.user, *active_organizations(person) ]
  end

  def person_related
    [ @commentable.user, *active_organizations(@commentable) ]
  end

  def organization_related
    @commentable.people.merge(Affiliation.active).distinct.to_a
  end

  def user_related
    person = @commentable.person
    return [] unless person

    [ person, *active_organizations(person) ]
  end

  def workshop_related
    creator = @commentable.created_by
    return [] unless creator

    [ creator, creator.person, *(creator.person ? active_organizations(creator.person) : []) ]
  end

  def active_organizations(person)
    person.organizations.merge(Affiliation.active).distinct.to_a
  end
end
