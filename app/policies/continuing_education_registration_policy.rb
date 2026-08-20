class ContinuingEducationRegistrationPolicy < ApplicationPolicy
  # Registrants manage their license via the public CE callout - not this policy.
  alias_rule :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, :toggle_certificate?, to: :manage?

  def manage? = admin?
end
