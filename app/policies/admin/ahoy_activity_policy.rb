module Admin
  class AhoyActivityPolicy < ApplicationPolicy
    # See https://actionpolicy.evilmartians.io/#/writing_policies

    def index?
      admin?
    end

    def charts?
      admin?
    end

    def visits?
      admin?
    end

    # Scoping
    # See https://actionpolicy.evilmartians.io/#/scoping
    #
    # relation_scope do |relation|
    #   next relation if admin?
    #   relation.where(user: user)
    # end
  end
end
