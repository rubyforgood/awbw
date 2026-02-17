class DedupePolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  def index?
    admin?
  end

  def preview?
    admin?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping
  #
  # relation_scope do |relation|
  #   next relation if admin?
  #   relation.where(user: user)
  # end
end
