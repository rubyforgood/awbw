class StoryPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  def index?
    true
  end

  def share_portal?
    true
  end

  def show?
    admin? || record.publicly_visible? || (authenticated? && record.published?)
  end

  def show_share_portal?
    show?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping
  #
  relation_scope do |relation|
    next relation if admin?
    if authenticated?
      relation.published
    else
      relation.publicly_visible
    end
  end
end
