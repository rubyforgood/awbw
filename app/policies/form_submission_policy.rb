class FormSubmissionPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  def show?
    admin?
  end
end
