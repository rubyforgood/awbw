# frozen_string_literal: true

class BookmarkPolicy < ApplicationPolicy
  # personal and tally are custom actions that require authentication (handled by pre_check)
  alias_rule :personal?, :tally?, to: :index?

  def destroy?
    admin? || owner?
  end

  private

  def owner?
    record.user_id == user.id
  end
end
