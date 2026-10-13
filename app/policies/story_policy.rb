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
    scope = relation.not_funder_only
    if authenticated?
      scope.published
    else
      scope.publicly_visible
    end
  end

  private

  # The named author, a credited co-author, or the submitter — the people who
  # may see their own story even when it's funder-only.
  def own_story?
    return false unless user
    person_id = user.person_id
    (person_id.present? && [ record.author_id, record.co_author_id ].include?(person_id)) ||
      record.created_by_id == user.id
  end
end
