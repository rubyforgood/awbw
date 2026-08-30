module UserStampable
  extend ActiveSupport::Concern

  # Stamps created_by_id / updated_by_id from Current.user so attribution lives on the
  # record itself instead of being assigned by hand in every controller. Included on
  # ApplicationRecord; the guards make it a no-op for tables without the columns, and
  # the whole thing is a no-op when Current.user is nil (seeds, jobs, unauthenticated
  # flows). Runs on before_validation so it satisfies a required belongs_to before the
  # presence check.
  included do
    before_validation :stamp_user_columns
  end

  private

  def stamp_user_columns
    user = Current.user
    return unless user

    stamp_created_by(user)
    stamp_updated_by(user)
  end

  # Only at creation, and always the authenticated actor — created_by is not a
  # user-supplied value, so a mass-assigned created_by_id must not override it. A
  # later editor never reaches this (guarded on new_record?), so it can't claim it.
  def stamp_created_by(user)
    return unless new_record? && has_attribute?(:created_by_id)

    self.created_by_id = user.id
  end

  def stamp_updated_by(user)
    return unless has_attribute?(:updated_by_id)

    # Skip when the caller set updated_by_id explicitly (respect it), and when nothing
    # else changed (don't turn a no-op save into a write / spurious update event).
    # A save whose only changes are to associations leaves the record itself unchanged,
    # so a parent that must bump when only its nested records change still assigns by hand.
    return if updated_by_id_changed?
    return unless new_record? || changed?

    self.updated_by_id = user.id
  end
end
