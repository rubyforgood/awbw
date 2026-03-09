class Faq < ApplicationRecord
  include Publishable
  positioned

  has_many :bookmarks, as: :bookmarkable, dependent: :destroy

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
    if visibility_params_present?(params)
      results = apply_visibility_filters(results, params)
    elsif params[:published].present?
      results = results.published(params[:published])
    end
    results
  end

  def name
    question
  end
end
