class Faq < ApplicationRecord
  # TODO After the production db migration we should "heal_ordering_column!" and add db contraints
  # https://github.com/brendon/positioning
  positioned on: [], column: :ordering

  # Validations
  validates_presence_of :question, :answer

  # Scopes
  scope :active, -> { where(inactive: false) }
  scope :by_order, -> { order(ordering: :asc) }
end
