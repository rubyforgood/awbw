# A name FileMaker stamped on a record's EnteredBy/ModifiedBy, and the portal user it means.
# The archive recorded staff as free text — full names, first names, role logins, the odd
# email — so an import looks each one up here to fill created_by/updated_by. The rows are
# loaded from a staff list kept outside the repo (`data:load_staff_aliases`), since they
# pair real names with real accounts.
#
# A shared login like "Staff" or "Volunteer" is recorded as naming no one on purpose, which
# keeps it out of the names still needing a decision.
class StaffAlias < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  normalizes :name, with: ->(value) { value.to_s.squish }

  validates :name, presence: true, length: { maximum: 255 }, uniqueness: { case_sensitive: false }
  validate :names_a_user_or_is_ignored

  scope :ignored, -> { where(ignored: true) }
  scope :resolving, -> { where(ignored: false) }

  private

  def names_a_user_or_is_ignored
    return if user.present? ^ ignored?

    errors.add(:base, "A staff name either names a user or is ignored, not both and not neither")
  end
end
