# frozen_string_literal: true

class CategoryPolicy < ApplicationPolicy
  alias_rule :edit?, to: :update?
end
