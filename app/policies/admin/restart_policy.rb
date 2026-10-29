module Admin
  class RestartPolicy < ApplicationPolicy
    def show?
      admin?
    end

    def create?
      admin?
    end
  end
end
