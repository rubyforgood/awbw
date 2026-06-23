class OrganizationType < ApplicationRecord
  include NameFilterable, Publishable

  # Canonical classifications offered on the organization profile and public
  # registration forms. Seeded as published records (see db/seeds.rb) and used
  # as the fallback list when no published types exist yet (e.g. a fresh test
  # database without seeds), so the forms always have sensible options.
  DEFAULT_NAMES = [
    "501c3/nonprofit",
    "For-profit",
    "Government agency",
    "Other"
  ].freeze

  has_many :organizations, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Names sort cleanly: digits precede letters, so "501c3/nonprofit" leads and
  # "Other" trails — exactly the intended display order.
  scope :ordered, -> { order(:name) }
  scope :name_contains, ->(term) { term.present? ? where("name LIKE ?", "%#{sanitize_sql_like(term)}%") : all }

  # Published names for the forms, falling back to the canonical defaults when
  # nothing is seeded yet.
  def self.published_names
    published.ordered.pluck(:name).presence || DEFAULT_NAMES
  end

  scope :filter_scope, ->(params) do
    filtered = all
    filtered = filtered.name_contains(params[:name])
    filtered = filtered.published if params[:published] == "true"
    filtered = filtered.where(published: false) if params[:published] == "false"
    filtered
  end
end
