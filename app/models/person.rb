class Person < ApplicationRecord
  include TagFilterable, Trendable, WindowsTypeFilterable

  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  has_one :user, inverse_of: :person, dependent: :nullify
  has_many :organization_people, dependent: :destroy
  has_many :organizations, through: :organization_people
  has_many :communal_reports, through: :organizations, source: :reports
  has_many :windows_types, through: :organizations

  has_many :addresses, as: :addressable, dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :contact_methods, as: :contactable, dependent: :destroy
  has_many :categorizable_items, inverse_of: :categorizable, as: :categorizable, dependent: :destroy
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  has_many :stories_as_spotlighted_facilitator, inverse_of: :spotlighted_facilitator, class_name: "Story",
           dependent: :restrict_with_error
  # has_many through
  has_many :event_registrations, through: :user
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  # Asset associations
  has_one_attached :avatar, dependent: :purge do |attachable|
    attachable.variant :thumbnail,
      resize_to_limit: [ 256, 256 ],
      format: :webp,
      saver: { quality: 80 }
  end

  # Validations
  validates :avatar,
            content_type: %w[image/png image/jpeg image/webp],
            size: { less_than: 5.megabytes },
            unless: -> { Rails.env.test? }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_blank: true
  validates :email_2, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_blank: true

  CONTACT_TYPES = [ "work", "personal" ].freeze
  validates :email_type, inclusion: { in: %w[work personal] }, allow_blank: true
  validates :email_2_type, inclusion: { in: %w[work personal] }, allow_blank: true
  # TODO: add validation for zip code containing only numbers
  # TODO: add validation on STATE
  # TODO: add validation on phone number type

  # Nested attributes
  accepts_nested_attributes_for :addresses, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :contact_methods, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :sectorable_items, allow_destroy: true,
                                reject_if: proc { |attrs| attrs["sector_id"].blank? }
  accepts_nested_attributes_for :user, update_only: true
  accepts_nested_attributes_for :organization_people, allow_destroy: true,
    reject_if: proc { |attrs| attrs["organization_id"].blank? || attrs["title"].blank? }

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes :first_name, :last_name, :email, :email_2
    attributes user_first_name: "user.first_name"
    attributes user_last_name:  "user.last_name"
    attributes user_email:      "user.email"
    attributes user_phone:      "user.phone"
    attributes contact_methods_phone: "contact_methods.value"
  end

  scope :published, -> { searchable.with_active_affiliations }
  scope :searchable, ->(searchable = nil) { searchable ? where(profile_is_searchable: searchable) : where(profile_is_searchable: true) }
  scope :with_active_affiliations, -> {
    joins(:organization_people)
      .merge(OrganizationPerson.active)
      .distinct
  }
  scope :organization_name, ->(organization_name) {
    return all if organization_name.blank?
    left_joins(organization_people: :organization)
      .where("organizations.name LIKE ?", "%#{sanitize_sql_like(organization_name)}%")
      .distinct }
  scope :organization_id, ->(organization_id) {
    joins(:organization_people)
      .where(organization_people: { organization_id: organization_id })
      .distinct }

  def self.search_by_params(params)
    results = is_a?(ActiveRecord::Relation) ? self : all
    results = results.search(params[:contact_info]) if params[:contact_info].present?
    results = results.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    results = results.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    results = results.organization_name(params[:organization_name]) if params[:organization_name].present?
    results = results.organization_id(params[:organization_id]) if params[:organization_id].present?
    results = results.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    results
  end

  def published?
    profile_is_searchable? && organization_people.active.exists?
  end

  def sector_list
    sectors.pluck(:name)
  end

  def name
    case display_name_preference
    when "full_name"
      full_name
    when "first_name_last_initial"
      "#{first_name} #{last_name.first}"
    when "first_name_only"
      first_name
    when "last_name_only"
      last_name
    else
      full_name
    end
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def phone_number
    primary_phone = contact_methods.find_by(is_primary: true, inactive: false, kind: :phone)
    return primary_phone.value if primary_phone.present?

    first_phone = contact_methods.where(kind: :phone, inactive: false).first
    return first_phone.value if first_phone.present?

    nil
  end

  def has_liasion_position_for?(organization_id)
    !organization_people.where(organization_id: organization_id, position: 1).first.nil?
  end

  def published?
    profile_is_searchable? && organization_people.active.exists?
  end

  def primary_organization
    organization_people
      .active
      .order(updated_at: :desc)
      .first&.organization
  end
end
