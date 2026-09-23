class InvoicePolicy < ApplicationPolicy
  def manage? = admin?
  alias_rule :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, to: :manage?
end
