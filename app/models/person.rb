class Person < ApplicationRecord
  include RemoteSearchable, TagFilterable, Trendable, WindowsTypeFilterable

  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  has_one :user, inverse_of: :person, dependent: :nullify
  has_many :affiliations, dependent: :destroy
  has_many :organizations, through: :affiliations
  has_many :communal_reports, through: :organizations, source: :reports
  has_many :windows_types, through: :organizations

  has_many :addresses, as: :addressable, dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
  has_many :contact_methods, as: :contactable, dependent: :destroy
  has_many :categorizable_items, inverse_of: :categorizable, as: :categorizable, dependent: :destroy
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  has_many :stories_as_spotlighted_facilitator, inverse_of: :spotlighted_facilitator, class_name: "Story",
           dependent: :restrict_with_error
  # has_many through
  has_many :event_registrations, foreign_key: :registrant_id, dependent: :destroy
  has_many :events, through: :event_registrations
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  # Asset associations
  has_one_attached :avatar, dependent: :purge do |attachable|
    attachable.variant :thumbnail,
      resize_to_limit: [ 256, 256 ],
      format: :webp,
      saver: { quality: 80 }
  end

  before_validation :strip_whitespace

  # Validations
  validates :avatar,
            content_type: %w[image/png image/jpeg image/webp],
            size: { less_than: 5.megabytes },
            unless: -> { Rails.env.test? }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_blank: true
  validates :email_2, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_blank: true
  validate :unique_name_and_email_combination

  CONTACT_TYPES = [ "work", "personal" ].freeze
  validates :email_type, inclusion: { in: %w[work personal] }, allow_blank: true
  validates :email_2_type, inclusion: { in: %w[work personal] }, allow_blank: true
  # TODO: add validation for zip code containing only numbers
  # TODO: add validation on STATE
  # TODO: add validation on phone number type

  # Nested attributes
  accepts_nested_attributes_for :addresses, allow_destroy: true,
                                reject_if: proc { |attrs| attrs.slice("locality", "city", "state", "street_address", "zip_code").values.all?(&:blank?) }
  accepts_nested_attributes_for :contact_methods, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :sectorable_items, allow_destroy: true,
                                reject_if: proc { |attrs| attrs["sector_id"].blank? }
  accepts_nested_attributes_for :user, update_only: true
  accepts_nested_attributes_for :affiliations, allow_destroy: true,
    reject_if: proc { |attrs| attrs["organization_id"].blank? }
  accepts_nested_attributes_for :comments, reject_if: proc { |attrs| attrs["body"].blank? }

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes :first_name, :last_name, :email, :email_2

    scope { left_joins(:user, :contact_methods, :addresses) }
    attributes user_first_name: "user.first_name"
    attributes user_last_name:  "user.last_name"
    attributes user_email:      "user.email"
    attributes user_phone:      "user.phone"
    attributes contact_methods_phone: "contact_methods.value"
    attributes address_street: "addresses.street_address"
    attributes address_city:   "addresses.city"
    attributes address_state:  "addresses.state"
    attributes address_zip:    "addresses.zip_code"
    attributes address_phone:  "addresses.phone"

    attributes all: [ :first_name, :last_name, :email, :email_2,
                      "user.first_name", "user.last_name", "user.email", "user.phone",
                      "contact_methods.value",
                      "addresses.street_address", "addresses.city", "addresses.state",
                      "addresses.zip_code", "addresses.phone" ]
    options :all, type: :text, default: true, default_operator: :or
  end

  scope :organization_ids, ->(organization_ids)  { joins(:affiliations)
                                                     .where(affiliations: { organization_id: organization_ids }) }
  scope :published, -> { searchable.with_active_affiliations }
  scope :searchable, ->(searchable = nil) { searchable ? where(profile_is_searchable: searchable) : where(profile_is_searchable: true) }
  scope :with_active_affiliations, -> {
    joins(:affiliations)
      .merge(Affiliation.active)
      .distinct
  }
  scope :organization_name, ->(organization_name) {
    return all if organization_name.blank?
    left_joins(affiliations: :organization)
      .where("organizations.name LIKE ?", "%#{sanitize_sql_like(organization_name)}%")
      .distinct }
  scope :organization_id, ->(organization_id) {
    joins(:affiliations)
      .where(affiliations: { organization_id: organization_id })
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
    profile_is_searchable? && affiliations.active.exists?
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

  def full_name_with_email
    email = preferred_email
    name = full_name
    if email.present? && name != email
      "#{name} (#{email})"
    else
      name
    end
  end

  def organization_ids
    organizations.pluck(:id)
  end

  def phone_number
    primary_phone = contact_methods.find_by(primary: true, inactive: false, kind: :phone)
    return primary_phone.value if primary_phone.present?

    first_phone = contact_methods.where(kind: :phone, inactive: false).first
    return first_phone.value if first_phone.present?

    nil
  end

  def has_liasion_position_for?(organization_id)
    !affiliations.where(organization_id: organization_id, position: 1).first.nil?
  end

  def primary_organization
    affiliations
      .active
      .order(updated_at: :desc)
      .first&.organization
  end

  def preferred_email
    user&.email.presence || email.presence || email_2.presence
  end

  remote_searchable_by :first_name, :last_name

  def remote_search_label
    {
      id: id,
      label: preferred_email.present? ?
        "#{full_name} (#{preferred_email})" :
        full_name
    }
  end

  private

  def strip_whitespace
    self.first_name = first_name&.strip
    self.last_name = last_name&.strip
    self.email = email&.strip
    self.email_2 = email_2&.strip
  end

  def unique_name_and_email_combination
    return unless first_name.present? && last_name.present?

    scope = Person.where(
      "LOWER(first_name) = ? AND LOWER(last_name) = ?",
      first_name.downcase,
      last_name.downcase
    )

    if email.present?
      scope = scope.where("LOWER(email) = ?", email.downcase)
    else
      scope = scope.where(email: [ nil, "" ])
    end

    scope = scope.where.not(id: id) if persisted?

    if scope.exists?
      errors.add(:base, "A person named #{first_name} #{last_name} with this email already exists")
    end
  end
end
