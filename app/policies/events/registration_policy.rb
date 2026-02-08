class Events::RegistrationPolicy < ApplicationPolicy
  def manage?  = admin? || owner?

  def create?
    authenticated?
  end

  def destroy?
    admin? || owner?
  end

  private

  def owner?
    return false unless user
    record.registrant_id == user.id
  end
end
