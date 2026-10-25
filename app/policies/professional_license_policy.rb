class ProfessionalLicensePolicy < ApplicationPolicy
  alias_rule :new?, :create?, :update?, to: :edit?

  # Admin-only browse index (owners manage their own licenses on the person form).
  def index? = admin?

  # Locked to admins once any CE registration is attached.
  def edit?
    admin? || (owner? && !record.used_for_ce?)
  end

  def destroy?
    edit? && record.removable?
  end

  private

  def owner?
    authenticated? && user.person_id.present? && user.person_id == record.person_id
  end
end
