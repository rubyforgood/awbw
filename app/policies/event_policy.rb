class EventPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  def index?
    true
  end

  def show?
    admin? || record.publicly_visible? || (authenticated? && record.published?)
  end

  def register?
    authenticated? && record.published?
  end

  relation_scope do |relation|
    next relation if admin?
    if authenticated? # logged in users can see events they are registered for even if registration is closed
      relation.left_outer_joins(:registrants)
              .published
              .where("registration_close_date IS NULL OR registration_close_date >= ? OR users.id = ?", Time.current, user.id)
              .distinct
    else
      relation.publicly_visible
              .published
              .where("registration_close_date IS NULL OR registration_close_date >= ?", Time.current)
    end
  end
end
