class Faq < ApplicationRecord
  # Validations
  validates_presence_of :question, :answer

  # Scopes
  scope :active, -> { where(inactive: false) }
  scope :by_order, -> { order(ordering: :asc) }
end
