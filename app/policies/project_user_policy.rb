# frozen_string_literal: true

class ProjectUserPolicy < ApplicationPolicy
  def destroy?
    admin?
  end
end
