module Admin
  # The resource-roles page sets which Resource fills each built-in role
  # (certificate artwork, the W-9, training handouts). Same bar as the rest of the
  # admin namespace — super-user only.
  class ResourceRolesPolicy < ApplicationPolicy
    def show?
      admin?
    end

    def update?
      admin?
    end
  end
end
