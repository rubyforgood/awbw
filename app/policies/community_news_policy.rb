# frozen_string_literal: true

class CommunityNewsPolicy < ApplicationPolicy
  # scope published vs all
  alias_rule :edit?, to: :update?

  # Scope for community news index - admins see all, others see published
  scope_for :relation do |relation|
    if admin?
      relation.all
    else
      relation.published
    end
  end
end
