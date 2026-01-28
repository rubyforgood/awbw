# frozen_string_literal: true

class FaqPolicy < ApplicationPolicy
  # scope active vs all
  alias_rule :edit?, to: :update?

  # Scope for FAQ index - admins see all, others see active
  scope_for :relation do |relation|
    if admin?
      relation.all
    else
      relation.active
    end
  end
end
