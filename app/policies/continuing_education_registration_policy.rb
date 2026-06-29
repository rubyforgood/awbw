class ContinuingEducationRegistrationPolicy < ApplicationPolicy
  # The CE registration edit page (license/hours/cost, certificate issuance,
  # removal) is an admin management surface, like scholarships. Registrants edit
  # their own license number via the public CE callout, not here.
  def edit?               = admin?
  def update?             = admin?
  def destroy?            = admin?
  def toggle_certificate? = admin?
end
