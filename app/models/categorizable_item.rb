class CategorizableItem < ApplicationRecord
  attr_accessor :_create

  belongs_to :categorizable, polymorphic: true, optional: true
  belongs_to :category

  # Validations
  # Note: categorizable_id will be set by Rails when the parent is saved
  # so we don't validate its presence during build phase
  validates_presence_of :categorizable_type, :category_id
  validates :category_id, uniqueness: { scope: [ :categorizable_type, :categorizable_id ] }, if: -> { categorizable_id.present? }
end
