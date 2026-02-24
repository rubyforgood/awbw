class Events::PublicRegistrationPolicy < ApplicationPolicy
  def new?
    true
  end

  def create?
    true
  end

  def show?
    authenticated?
  end
end
