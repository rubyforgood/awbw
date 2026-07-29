class FormSubmissionPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  authorize :slug, optional: true, allow_nil: true

  def index?
    admin?
  end

  def show?
    admin? || (slug.present? && record.slug == slug)
  end

  def ticket?
    admin? || (slug.present? && record.slug == slug)
  end

  # The payer edits their own submission's attendee list via its public slug;
  # admins can edit any submission.
  def edit?
    admin? || (slug.present? && record.slug == slug)
  end

  def update?
    admin? || (slug.present? && record.slug == slug)
  end

  def new?
    true
  end

  def create?
    true
  end

  # Bulk-payment payers have no account but are emailed a link to their public
  # submission, so they can reach its invoice too. Other submission types stay
  # admin-only.
  def show_invoice?
    record.role == "bulk_payment" || admin?
  end
end
