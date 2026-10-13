class InvoicePolicy < ApplicationPolicy
  alias_rule :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, to: :manage?

  def manage? = admin?
end
