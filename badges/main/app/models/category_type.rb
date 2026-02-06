class CategoryType < ApplicationRecord
  include Publishable

  has_many :categories, class_name: "Category", foreign_key: :category_type_id, dependent: :destroy
  has_many :categorizable_items, through: :categories, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Scopes
  # See Publishable
end
