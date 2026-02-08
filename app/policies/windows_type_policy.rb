class WindowsTypePolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  relation_scope do |relation|
    next relation if admin?
    relation.none
  end
end
