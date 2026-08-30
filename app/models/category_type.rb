class CategoryType < ApplicationRecord
  include Publishable

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :categories, class_name: "Category", foreign_key: :category_type_id, dependent: :destroy
  has_many :categorizable_items, through: :categories, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }
  validates :display_text, length: { maximum: 255 }

  # Scopes
  # See Publishable
  scope :general, -> { where(story_specific: false, profile_specific: false) }
  scope :story_specific, -> { where(story_specific: true) }
  scope :profile_specific, -> { where(profile_specific: true) }

  def display_label
    display_text.presence || name.underscore.humanize
  end
end
