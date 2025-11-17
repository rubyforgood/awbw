class Project < ApplicationRecord
  # Associations
  belongs_to :location, optional: true
  belongs_to :project_status
  belongs_to :windows_type, optional: true
  has_many :addresses, as: :addressable, dependent: :destroy
  has_many :project_users, dependent: :restrict_with_error
  has_many :users, through: :project_users
  has_many :reports, through: :users
  has_many :workshop_logs, through: :users
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  has_many :sectors, through: :sectorable_items

  # Logo
  ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png" ].freeze
  has_one_attached :logo
  validates :logo, content_type: ACCEPTED_CONTENT_TYPES

  validates :name, presence: true
  validates :project_status_id, presence: true

  accepts_nested_attributes_for :addresses, allow_destroy: true

  scope :active, -> { where(inactive: false) }

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes :name
  end

  scope :address, ->(address) do
    return all if address.blank?
    q = "%#{address}%"
    left_joins(:addresses).where("
      addresses.street_address LIKE :q OR
      addresses.city LIKE :q OR
      addresses.state LIKE :q OR
      addresses.county LIKE :q OR
      addresses.country LIKE :q OR
      addresses.district LIKE :q OR
      addresses.locality LIKE :q OR
      addresses.zip_code = :q OR
      CAST(addresses.la_city_council_district AS CHAR) = '#{address}' OR
      CAST(addresses.la_service_planning_area AS CHAR) = '#{address}' OR
      CAST(addresses.la_supervisorial_district AS CHAR) = '#{address}'", q: q)
  end
  scope :windows_type_name, ->(windows_type_name) { return all if windows_type_name.blank?
    joins(:windows_type).where("windows_types.name LIKE ?", "%#{ windows_type_name }%") }

  def self.search_by_params(params)
    projects = Project.all
    projects = projects.search(params[:query]) if params[:query].present?
    projects = projects.address(params[:address]) if params[:address].present?
    projects = projects.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    projects
  end

  # Methods
  def led_by?(user)
    return false unless leader
    leader.user == user
  end

  def log_title
    "#{name} #{windows_type.log_label if windows_type}"
  end

  def sector_list
    sectors.pluck(:name)
  end

  private

  def leader
    project_users.find_by(position: 2)
  end
end
