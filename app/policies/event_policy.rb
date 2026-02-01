class EventPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  skip_pre_check :verify_authenticated!

  relation_scope do |relation|
    if admin?
      relation
    else
      relation.left_outer_joins(:registrants)
              .where(publicly_visible: true)
              .where("registration_close_date IS NULL OR registration_close_date >= ? OR users.id = ?", Time.current, user.id)
              .distinct
    end
  end
end
