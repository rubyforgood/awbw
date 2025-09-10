# frozen_string_literal: true

class Metadatum < ApplicationRecord
  has_many :categories, dependent: :destroy
  has_many :categorizable_items, through: :categories, dependent: :destroy
  # Validations
  validates :name, presence: { uniqueness: true }

  scope :published, -> { where(published: true) }
end
