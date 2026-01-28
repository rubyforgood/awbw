# frozen_string_literal: true

class ResourcePolicy < ApplicationPolicy
  # scope published vs all
  alias_rule :edit?, to: :update?
  alias_rule :download?, to: :show?
  alias_rule :stories?, :search?, to: :index?

  # Scope for resource index - admins see all, others see published kinds
  scope_for :relation do |relation|
    if admin?
      relation.all
    else
      relation.where(kind: Resource::PUBLISHED_KINDS)
    end
  end
end
