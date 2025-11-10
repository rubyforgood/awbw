class Faq < ApplicationRecord
  # TODO After the production db migration we should "heal_ordering_column!" and add db contraints
  # https://github.com/brendon/positioning
  positioned on: [], column: :ordering

  # Validations
  validates_presence_of :question, :answer

  # Scopes
  scope :active, -> { where(inactive: false) }
  scope :by_order, -> { order(ordering: :asc) }

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes [:question, :answer]
  end

  def self.search_by_params(params)
    results = self.all
    results = results.search(params[:query]) if params[:query].present?
    if params[:inactive].to_s.present?
      value = ActiveModel::Type::Boolean.new.cast(params[:inactive])
      results = results.where(inactive: value)
    end
    results
  end

  def name
    question
  end
end
