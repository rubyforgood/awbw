class CategoryType < ApplicationRecord
  self.table_name = "metadata"

  has_many :categories, class_name: "Category", foreign_key: :metadatum_id, dependent: :destroy
  has_many :categorizable_items, through: :categories, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :published, -> { where(published: true) }
end
