module UserStampable
  extend ActiveSupport::Concern

  # Stamps updated_by_id from Current.user on every write, so the last editor is
  # recorded on the record itself. (created_by_id is set at create time by the
  # controllers; only updated_by_id was going unset on updates.) Included on
  # ApplicationRecord; the guard makes it a no-op for tables without the column. Runs
  # on before_validation so it satisfies a required belongs_to :updated_by before the
  # presence check.
  included do
    before_validation :stamp_updated_by
  end

  private

  def stamp_updated_by
    user = Current.user
    return unless user
    return unless has_attribute?(:updated_by_id)

    # Skip when the caller set updated_by_id explicitly (respect it), and when nothing
    # else changed (don't turn a no-op save into a write / spurious update event).
    return if updated_by_id_changed?
    return unless new_record? || changed?

    self.updated_by_id = user.id
  end
end
