class OtherResponsePolicy < ApplicationPolicy
  # Curating free-text "Other" responses (reviewing, promoting, keeping,
  # dismissing) is an admin-only task. index?/update? fall back to manage?.

  def promote?
    admin?
  end
end
