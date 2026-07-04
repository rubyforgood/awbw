class FormSubmissionPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  def index?
    admin?
  end

  def show?
    admin?
  end

  # Bulk-payment payers have no account but are emailed a link to their public
  # submission, so they can reach its invoice too. Other submission types stay
  # admin-only.
  def show_invoice?
    record.role == "bulk_payment" || admin?
  end
end
