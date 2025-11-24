class Metadatum < ApplicationRecord
  has_many :categories, dependent: :destroy
  has_many :categorizable_items, through: :categories, dependent: :destroy

  # Validations
  validates_presence_of :name, uniqueness: true

  scope :published, -> { where(published: true) }
end
