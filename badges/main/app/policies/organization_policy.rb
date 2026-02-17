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

  def populations_served?
    show?
  end


  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.published
  end

  relation_scope(:affiliated) do |relation|
    next relation.active if admin?
    next relation.none unless user&.person_id

    relation.joins(:affiliations)
            .where(affiliations: { person_id: user.person_id })
  end

  private

  def member?
    @member ||= begin
      return false unless user&.person_id
      record.affiliations.exists?(person_id: user.person_id)
    end
  end
end
