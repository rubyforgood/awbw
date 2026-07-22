class Events::BulkPaymentPolicy < ApplicationPolicy
  def new?
    true
  end

  def create?
    true
  end

  def show?
    true
  end

  def ticket?
    true
  end

  def pay?
    true
  end
end
