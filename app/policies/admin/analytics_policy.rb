module Admin
  class AnalyticsPolicy < ApplicationPolicy
    # See https://actionpolicy.evilmartians.io/#/writing_policies

    def index?
      admin?
    end

    def print?
      true # anyone should be able to print
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
