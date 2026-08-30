module Admin
  class DataHealthPolicy < ApplicationPolicy
    def index?
      admin?
    end

    # Repairs delete or rewrite rows across the whole database. Same bar as the
    # page itself — `admin?` is already super-user only — but spelled out so
    # tightening one without the other is a deliberate edit.
    def repair?
      admin?
    end
  end
end
