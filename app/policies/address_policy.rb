class AddressPolicy < ApplicationPolicy
  def enter_any_state? = admin?
end
