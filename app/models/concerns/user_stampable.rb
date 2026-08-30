module UserStampable
  extend ActiveSupport::Concern

  # Stamps the audit columns from Current.user so a record records who created and who
  # last edited it, without every controller assigning them by hand. Included on
  # ApplicationRecord; each stamp is a no-op for tables that lack the column, and the
  # whole thing is a no-op when Current.user is nil (seeds, jobs, unauthenticated
  # flows). Runs on before_validation so it satisfies a required belongs_to before the
  # presence check. Both stamps respect a value the caller assigned explicitly.
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

  # created_by is set once, at create time, and never overwritten afterward.
  def stamp_created_by(user)
    return unless new_record?
    return unless has_attribute?(:created_by_id)
    return if created_by_id.present?

    self.created_by_id = user.id
  end

  # updated_by tracks the last editor on every write. Skip when the caller set it
  # explicitly, and when nothing else changed (so a no-op save stays a no-op).
  def stamp_updated_by(user)
    return unless has_attribute?(:updated_by_id)
    return if updated_by_id_changed?
    return unless new_record? || changed?

    self.updated_by_id = user.id
  end
end
