class Category < ApplicationRecord
  belongs_to :metadatum
  has_many :categorizable_items, dependent: :destroy
  has_many :workshops, through: :categorizable_items, source: :categorizable, source_type: 'Workshop'

  scope :published, -> { where(published: true) }

  # Validations
  validates_presence_of :name, uniqueness: true
end
