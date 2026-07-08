class OtherResponsePolicy < ApplicationPolicy
  # Reviewing and curating free-text "Other" responses (promote/keep/dismiss) is
  # an admin-only task. Defined explicitly rather than leaning on the inherited
  # manage? fallback, matching how the other policies spell out their rules.

  def index?
    admin?
  end

  def update?
    admin?
  end

  def curate?
    admin?
  end

  def promote?
    admin?
  end
end
