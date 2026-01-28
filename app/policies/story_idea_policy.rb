# frozen_string_literal: true

class StoryIdeaPolicy < ApplicationPolicy
  alias_rule :edit?, to: :update?
end
