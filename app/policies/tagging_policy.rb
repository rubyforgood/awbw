# frozen_string_literal: true

class TaggingPolicy < ApplicationPolicy
  alias_rule :matrix?, to: :index?
end
