class Faq < ApplicationRecord
  include Publishable
  positioned

  # Validations
  validates_presence_of :question, :answer

  # Scopes
  # See Publishable
  scope :by_position, -> { order(position: :asc) }

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes [ :question, :answer ]
  end

  def self.search_by_params(params)
    results = self
    results = results.search(params[:query]) if params[:query].present?
    if params[:published].to_s.present?
      value = ActiveModel::Type::Boolean.new.cast(params[:published])
      results = results.where(published: value)
    end
    results
  end

  def name
    question
  end
end
