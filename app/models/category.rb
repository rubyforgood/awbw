class Category < ApplicationRecord
  # Associations
  belongs_to :metadatum
  has_many :categorizable_items, dependent: :destroy
  has_many :workshops, through: :categorizable_items, source: :categorizable, source_type: 'Workshop'
  default_scope { order('name') }
  scope :published, -> { where(published: true) }
  # Validations
  validates_presence_of :name, uniqueness: true
end
