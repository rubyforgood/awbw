class ProfessionalLicensePolicy < ApplicationPolicy
  alias_rule :new?, :create?, :update?, to: :edit?

  # Locked to admins once any CE registration is attached.
  def edit?
    admin? || (owner? && !record.used_for_ce?)
  end

  def destroy?
    edit? && record.removable?
  end

  private

  def owner?
    authenticated? && record.person&.user == user
  end
end
