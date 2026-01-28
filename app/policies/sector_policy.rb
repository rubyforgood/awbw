# frozen_string_literal: true

class SectorPolicy < ApplicationPolicy
  alias_rule :edit?, to: :update?
end
