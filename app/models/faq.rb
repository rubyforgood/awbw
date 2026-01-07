class Faq < ApplicationRecord
  positioned

  # Validations
  validates_presence_of :question, :answer

  # Scopes
  scope :active, -> { where(inactive: false) }
  scope :by_position, -> { order(position: :asc) }

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes [ :question, :answer ]
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
