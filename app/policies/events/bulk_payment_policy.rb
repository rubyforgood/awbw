class Events::BulkPaymentPolicy < ApplicationPolicy
  def new?
    true
  end

  def create?
    true
  end

  def ticket?
    true
  end
end
