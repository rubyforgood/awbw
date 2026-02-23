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
    results = is_a?(ActiveRecord::Relation) ? self : all
    results = results.search(params[:query]) if params[:query].present?
    case params[:published].to_s
    when "publicly_visible"
      results = results.publicly_visible
    when "true"
      results = results.where(published: true)
    when "false"
      results = results.where(published: false)
    end
    results
  end

  def name
    question
  end
end
