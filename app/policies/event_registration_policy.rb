# frozen_string_literal: true

class EventRegistrationPolicy < ApplicationPolicy
  alias_rule :edit?, to: :update?
end
