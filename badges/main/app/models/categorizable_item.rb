class CategorizableItem < ApplicationRecord
  belongs_to :categorizable, polymorphic: true
  belongs_to :category
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  # Validations
  validates_presence_of :categorizable_type, :categorizable_id, :category_id
  validates :category_id, uniqueness: { scope: [ :categorizable_type, :categorizable_id ] }
end
