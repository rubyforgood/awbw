class OrganizationPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  def index?
    authenticated?
  end

  def show?
    admin? || (authenticated? && record.published?)
  end

  def show_workshop_logs?
    admin? || member?
  end


  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.published
  end

  # scope_for :affiliated, :relation do |relation|
  #   return relation if admin?
  #   return relation.none unless user&.person_id
  #
  #   relation.joins(:organization_people)
  #           .where(organization_people: { person_id: user.person_id })
  # end

  private

  def member?
    @member ||= begin
      return false unless user&.person_id
      record.organization_people.exists?(person_id: user.person_id)
    end
  end
end
