class StaffTaggingPolicy < ApplicationPolicy
  def edit?
    record.persisted? && admin?
  end

  def update?
    edit?
  end
end
