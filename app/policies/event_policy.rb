class EventPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  skip_pre_check :verify_authenticated!

  def show?
    admin? || !record&.inactive?
  end

  relation_scope do |relation|
    if admin?
      relation
    elsif authenticated?
      relation.left_outer_joins(:registrants)
              .where(inactive: false)
              .where("registration_close_date IS NULL OR registration_close_date >= ? OR users.id = ?", Time.current, user.id)
              .distinct
    else
      relation.where(inactive: false)
                .where("registration_close_date IS NULL OR registration_close_date >= ?", Time.current)
    end
  end
end
