# frozen_string_literal: true

class Faq < ApplicationRecord
  # Validations
  validates :question, :answer, presence: true

  # Scopes
  scope :active, -> { where(inactive: false) }
  scope :by_order, -> { order(ordering: :desc) }
end
