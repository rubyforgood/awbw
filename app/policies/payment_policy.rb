class PaymentPolicy < ApplicationPolicy
  def new_checkout_link?
    manage?
  end

  def create_checkout_link?
    manage?
  end
end
