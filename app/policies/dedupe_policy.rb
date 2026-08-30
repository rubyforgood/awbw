class DedupePolicy < ApplicationPolicy
  # One rollup rule gating every model's dedupe actions (index/preview/perform/
  # update_keep), so dedupe access can later be opened to non-admins in a single
  # place rather than per model. Admin-only for now.
  def dedupe?
    admin?
  end
end
