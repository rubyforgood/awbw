class Project < ApplicationRecord
  include TagFilterable, Trendable, ViewCountable, WindowsTypeFilterable

  belongs_to :project_status
  belongs_to :project_obligation, optional: true
  belongs_to :location, optional: true # TODO - remove Location if unused
  belongs_to :windows_type, optional: true
  has_many :addresses, as: :addressable, dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :project_users, dependent: :restrict_with_error
  has_many :users, through: :project_users
  has_many :reports, through: :users
  has_many :workshop_logs, through: :users

  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  # has_many through
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  # Asset associations
  has_one_attached :logo

  # Validations
  validates :logo,
            content_type: %w[image/png image/jpeg image/webp],
            size: { less_than: 5.megabytes }
  validates :name, presence: true
  validates :project_status_id, presence: true

  # Nested attributes
  accepts_nested_attributes_for :addresses, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :sectorable_items, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :project_users, allow_destroy: true, reject_if: :all_blank

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes :name
  end

  scope :address, ->(address) do
    return all if address.blank?
    exact = address.to_s
    wildcard = "%#{exact}%"
    left_joins(:addresses).where(
      <<~SQL,
      addresses.street_address LIKE :wildcard OR
      addresses.city LIKE :wildcard OR
      addresses.state LIKE :wildcard OR
      addresses.county LIKE :wildcard OR
      addresses.country LIKE :wildcard OR
      addresses.district LIKE :wildcard OR
      addresses.locality LIKE :wildcard OR
      addresses.zip_code LIKE :exact OR
      CAST(addresses.la_city_council_district AS CHAR) = :exact OR
      CAST(addresses.la_service_planning_area AS CHAR) = :exact OR
      CAST(addresses.la_supervisorial_district AS CHAR) = :exact
    SQL
      wildcard: wildcard, exact: exact)
  end
  scope :active, ->(active = nil) { active ? where(inactive: !active) : where(inactive: false) }
  scope :by_most_viewed, ->(limit = 10) { order(view_count: :desc).limit(limit) }
  scope :published, ->(published = nil) { published ? active(published) : active }
  scope :category_names, ->(names) { tag_names(:categories, names) }
  scope :sector_names,   ->(names) { tag_names(:sectors, names) }

  def self.search_by_params(params)
    projects = self.all
    projects = projects.search(params[:query]) if params[:query].present?
    projects = projects.sector_names(params[:sector_names]) if params[:sector_names].present?
    projects = projects.category_names(params[:category_names]) if params[:category_names].present?
    projects = projects.address(params[:address]) if params[:address].present?
    projects = projects.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    projects
  end

  # Methods
  def led_by?(user)
    return false unless leader
    leader.user == user
  end

  def type_name
    "#{name} #{ " (#{windows_type.short_name})" if windows_type}"
  end

  def organization_description
    "#{name}, #{organization_locality}"
  end

  def organization_locality
    addresses.active.first&.locality
  end

  def sector_list
    sectors.pluck(:name)
  end

  private

  def leader
    project_users.find_by(position: 2)
  end
end
