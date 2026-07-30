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

  def receipt?
    admin? || (slug.present? && record.slug == slug)
  end

  def new?
    true
  end

  def create?
    true
  end

  # Bulk-payment payers have no account but are emailed the unguessable slug, so
  # slug possession authorizes the invoice — same gate as #ticket / #receipt.
  # (Not keyed on the record id, which is enumerable.)
  def invoice?
    admin? || (slug.present? && record.slug == slug)
  end
end
