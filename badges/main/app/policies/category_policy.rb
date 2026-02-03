class CategoryPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  def tags_index?
    true
  end
end
