class Role < ApplicationRecord
  GLOBAL_ROLES = %w[super_admin member].freeze
  RESOURCE_ROLES = %w[manager].freeze
  ROLES = (GLOBAL_ROLES + RESOURCE_ROLES).freeze

  belongs_to :user
  belongs_to :roleable, polymorphic: true, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  scope :global, -> { where(roleable_type: nil, roleable_id: nil) }

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: {
    scope: %i[role roleable_type roleable_id],
    message: "already has this role for this roleable"
  }
  validate :role_scope_matches

  private

  def role_scope_matches
    return unless ROLES.include?(role)

    if GLOBAL_ROLES.include?(role) && (roleable_type.present? || roleable_id.present?)
      errors.add(:roleable, "must be blank for a global role")
    elsif RESOURCE_ROLES.include?(role) && roleable_type.blank? && roleable_id.blank?
      errors.add(:roleable, "must be present for a resource-scoped role")
    end
  end
end
