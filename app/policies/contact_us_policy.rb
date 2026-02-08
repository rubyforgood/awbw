class ContactUsPolicy < ApplicationPolicy
  # We default to the `manage?` rule, so we only need to define rules that differ from it.
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    true
  end

  def create?
    true
  end
end
