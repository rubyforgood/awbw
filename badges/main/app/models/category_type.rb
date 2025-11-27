class CategoryType < ApplicationRecord
	self.table_name = "metadata"

	has_many :categories, class_name: "Category", foreign_key: :metadatum_id, dependent: :destroy
	has_many :categorizable_items, through: :categories, dependent: :destroy

	# Validations
	validates_presence_of :name, uniqueness: true

	scope :published, -> { where(published: true) }
end
