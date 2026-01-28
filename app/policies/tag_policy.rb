# frozen_string_literal: true

class TagPolicy < ApplicationPolicy
  alias_rule :sectors?, :categories?, to: :index?
end
