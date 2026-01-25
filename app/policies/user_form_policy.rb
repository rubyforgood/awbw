# frozen_string_literal: true

class UserFormPolicy < ApplicationPolicy
  def create?
    authenticated?
  end
end
