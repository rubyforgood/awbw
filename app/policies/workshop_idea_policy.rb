# frozen_string_literal: true

class WorkshopIdeaPolicy < ApplicationPolicy
  alias_rule :edit?, to: :update?
end
