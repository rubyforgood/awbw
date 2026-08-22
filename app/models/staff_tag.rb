class StaffTag < ApplicationRecord
  include Publishable

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :staff_taggings, dependent: :restrict_with_error
  has_many :people, through: :staff_taggings, source: :staff_taggable, source_type: "Person"

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }

  scope :ordered, -> { order(:name) }

  def to_s
    name
  end
end
