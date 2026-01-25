# frozen_string_literal: true

class BookmarkPolicy < ApplicationPolicy
  def index?
    authenticated?
  end

  def show?
    authenticated?
  end

  def create?
    authenticated?
  end

  def destroy?
    admin? || owner?
  end

  def personal?
    authenticated?
  end

  def tally?
    authenticated?
  end

  private

  def owner?
    record.user_id == user.id
  end
end
