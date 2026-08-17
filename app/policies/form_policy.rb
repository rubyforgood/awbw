class FormPolicy < ApplicationPolicy
  # Admin-only — all CRUD actions inherit manage? from ApplicationPolicy

  # The public pretty-URL form. Open to anyone (no account), but only for a
  # standalone form its admin has deliberately published — never an event form or
  # an unpublished draft.
  def public_show?
    record.publicly_fillable?
  end
end
