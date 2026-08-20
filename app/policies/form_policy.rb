class FormPolicy < ApplicationPolicy
  # Admin-only — all CRUD actions inherit manage? from ApplicationPolicy

  # The public /f/:slug form — open to anyone, but only a published standalone form.
  def public_show?
    record.publicly_fillable?
  end
end
