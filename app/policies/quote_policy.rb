# frozen_string_literal: true

class QuotePolicy < ApplicationPolicy
  alias_rule :edit?, to: :update?
end
