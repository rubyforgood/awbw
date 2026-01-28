# frozen_string_literal: true

class FacilitatorPolicy < ApplicationPolicy
  alias_rule :edit?, to: :update?
end
