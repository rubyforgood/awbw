class DuesCheckoutPolicy < ApplicationPolicy
  def create? = Dues.enabled? && user&.person.present?
end
