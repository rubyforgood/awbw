class Person < ApplicationRecord
  include RemoteSearchable, TagFilterable, Trendable, WindowsTypeFilterable, SectorsTaggable, AgeGroupTaggable, StaffTaggable

  pay_customer default_payment_processor: :stripe

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_one :user, inverse_of: :person, dependent: :nullify
  has_many :affiliations, dependent: :destroy
  has_many :organizations, through: :affiliations
  has_many :professional_licenses, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :membership_invoices, through: :memberships
  has_many :communal_reports, through: :organizations, source: :reports
  has_many :windows_types, through: :organizations

  has_many :addresses, as: :addressable, dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
  has_many :contact_methods, as: :contactable, dependent: :destroy
  has_many :categorizable_items, inverse_of: :categorizable, as: :categorizable, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :nullify
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  has_many :other_responses, as: :owner, dependent: :destroy
  has_many :stories_as_spotlighted_facilitator, inverse_of: :spotlighted_facilitator, class_name: "Story",
           dependent: :restrict_with_error
  has_many :stories_as_author, inverse_of: :author, class_name: "Story", foreign_key: :author_id,
           dependent: :restrict_with_error
  has_many :workshop_variations_as_author, inverse_of: :author, class_name: "WorkshopVariation",
           foreign_key: :author_id, dependent: :restrict_with_error
  has_many :workshops_as_author, inverse_of: :author, class_name: "Workshop", foreign_key: :author_id,
           dependent: :restrict_with_error
  has_many :community_news_as_author, inverse_of: :author, class_name: "CommunityNews", foreign_key: :author_id,
           dependent: :restrict_with_error
  has_many :resources_as_author, inverse_of: :author, class_name: "Resource", foreign_key: :author_id,
           dependent: :restrict_with_error
  has_many :story_ideas_as_author, inverse_of: :author, class_name: "StoryIdea", foreign_key: :author_id,
           dependent: :restrict_with_error
  has_many :workshop_ideas_as_author, inverse_of: :author, class_name: "WorkshopIdea", foreign_key: :author_id,
           dependent: :restrict_with_error
  has_many :workshop_variation_ideas_as_author, inverse_of: :author, class_name: "WorkshopVariationIdea",
           foreign_key: :author_id, dependent: :restrict_with_error
  # has_many through
  has_many :event_registrations, foreign_key: :registrant_id, dependent: :destroy
  has_many :topic_subscriptions, dependent: :destroy
  has_many :event_staffs, dependent: :destroy
  has_many :scholarships, foreign_key: :recipient_id, dependent: :destroy
  has_many :grants, as: :funder, dependent: :destroy
  has_many :events, through: :event_registrations
  has_many :staffed_events, through: :event_staffs, source: :event
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items
  has_many :form_submissions, dependent: :destroy

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
  validates :first_name, presence: true, length: { maximum: 255 }
  validates :last_name, presence: true, length: { maximum: 255 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_blank: true, length: { maximum: 255 }
  validates :email_2, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_blank: true, length: { maximum: 255 }
  validates :legal_first_name, length: { maximum: 255 }
  validates :pronouns, length: { maximum: 255 }
  validates :pronunciation, length: { maximum: 255 }
  validates :best_time_to_call, length: { maximum: 255 }
  validates :racial_ethnic_identity, length: { maximum: 255 }
  validates :linked_in_url, length: { maximum: 255 }
  validates :facebook_url, length: { maximum: 255 }
  validates :instagram_url, length: { maximum: 255 }
  validates :youtube_url, length: { maximum: 255 }
  validates :twitter_url, length: { maximum: 255 }
  validate :unique_name_and_email_combination

  CONTACT_TYPES = [ "work", "personal" ].freeze
  validates :email_type, inclusion: { in: %w[work personal] }, allow_blank: true
  validates :email_2_type, inclusion: { in: %w[work personal] }, allow_blank: true

  # Anonymity isn't one of these — it's the separate `anonymous_contributions` flag,
  # since a person still has to be listed somehow on the people index.
  DISPLAY_NAME_PREFERENCES = %w[full_name first_name_last_initial first_name_only last_name_only].freeze

  DISPLAY_NAME_PREFERENCE_LABELS = {
    "full_name" => "First and last name",
    "first_name_last_initial" => "First name and last initial",
    "first_name_only" => "First name only",
    "last_name_only" => "Last name only"
  }.freeze

  validates :display_name_preference, inclusion: { in: DISPLAY_NAME_PREFERENCES }, allow_blank: true
  # Mirrors SectorsTaggable's single-primary rule for age ranges — the chip
  # editor's single-star JS is the first line of defense, this guards imports,
  # the console, and bad form posts. Person-only: organizations aggregate
  # several members' primary age groups, so they legitimately have more than one.
  validate :at_most_one_primary_age_range
  # TODO: add validation for zip code containing only numbers
  # TODO: add validation on STATE
  # TODO: add validation on phone number type

  # Nested attributes
  accepts_nested_attributes_for :addresses, allow_destroy: true,
                                reject_if: proc { |attrs| attrs.slice("locality", "city", "state", "street_address", "zip_code").values.all?(&:blank?) }
  accepts_nested_attributes_for :contact_methods, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :sectorable_items, allow_destroy: true,
                                reject_if: proc { |attrs| attrs["sector_id"].blank? }
  # Age ranges edit through cocoon nested fields like sectors. A scoped view of
  # categorizable_items (AgeRange categories only) so the form's add/remove and
  # primary toggle round-trip as nested attributes — the is_primary flag splits
  # primary vs additional, no separate primary_age_category_ids param needed.
  has_many :age_range_categorizable_items,
           -> { joins(category: :category_type).where(category_types: { name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE }) },
           class_name: "CategorizableItem", as: :categorizable, inverse_of: :categorizable
  accepts_nested_attributes_for :age_range_categorizable_items, allow_destroy: true,
                                reject_if: proc { |attrs| attrs["category_id"].blank? }
  # The picker can submit the same age range twice (two new rows), which the
  # CategorizableItem uniqueness validation can't catch — both are unsaved, so
  # both INSERT and hit the DB unique index. Collapse duplicates before validation.
  before_validation :dedupe_age_range_items
  accepts_nested_attributes_for :user, update_only: true
  accepts_nested_attributes_for :affiliations, allow_destroy: true,
    reject_if: proc { |attrs| attrs["organization_id"].blank? }
  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attrs| attrs["body"].blank? }
  accepts_nested_attributes_for :notifications, allow_destroy: true, reject_if: proc { |attrs| attrs["email_subject"].blank? }
  # A blank row (number + kind + state + expiry all empty) is ignored rather than
  # creating an empty license.
  accepts_nested_attributes_for :professional_licenses, allow_destroy: true,
    reject_if: proc { |attrs| attrs.slice("number", "kind", "issuing_state", "expires_on").values.all?(&:blank?) }

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes :first_name, :legal_first_name, :last_name, :email, :email_2

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

    attributes all: [ :first_name, :legal_first_name, :last_name, :email, :email_2,
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
  scope :where_user_not_locked, -> {
    left_joins(:user).where(users: { locked_at: nil }).or(
      left_joins(:user).where(users: { id: nil })
    )
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
  scope :sector_leaders, -> {
    joins(:sectorable_items).where(sectorable_items: { is_leader: true }).distinct }
  scope :staff_tagged_with, ->(ids) {
    tag_ids = Array(ids).reject(&:blank?)
    return all if tag_ids.empty?
    joins(:staff_taggings).where(staff_taggings: { staff_tag_id: tag_ids }).distinct }
  scope :story_authors, -> { joins(:stories_as_author).distinct }
  scope :blog_authors, -> { joins(:community_news_as_author).distinct }
  scope :workshop_authors, -> { joins(:workshops_as_author).distinct }
  scope :workshop_variation_authors, -> { joins(:workshop_variations_as_author).distinct }
  # WorkshopLog has no author column — it is created_by a User, so "author" here
  # means the person whose linked user account created the log.
  scope :workshop_log_authors, -> {
    creator_user_ids = WorkshopLog.where.not(created_by_id: nil).select(:created_by_id)
    where(id: User.where(id: creator_user_ids).where.not(person_id: nil).select(:person_id)) }
  # People with at least one currently-active facilitator affiliation.
  scope :facilitators_active, -> {
    where(id: Affiliation.facilitators.active.select(:person_id)) }
  # People with facilitator affiliation(s) but none currently active.
  scope :facilitators_inactive, -> {
    where(id: Affiliation.facilitators.select(:person_id))
      .where.not(id: Affiliation.facilitators.active.select(:person_id)) }
  # Not currently active, but a past facilitator term genuinely ended (real end
  # date in the past) — distinguishes "used to facilitate" from merely flagged inactive.
  scope :facilitators_formerly_active, -> {
    ended = Affiliation.facilitators.where.not(end_date: nil)
      .where("affiliations.end_date < ?", Date.current).select(:person_id)
    where(id: ended).where.not(id: Affiliation.facilitators.active.select(:person_id)) }
  # Facilitators tied to 2+ facilitator affiliations with at least one still active
  # (e.g. moved between partner orgs, or serve more than one at once).
  scope :boomerang_facilitators, -> {
    multiple = Affiliation.facilitators.group(:person_id).having("COUNT(affiliations.id) >= 2").select(:person_id)
    where(id: multiple).where(id: Affiliation.facilitators.active.select(:person_id)) }
  scope :by_facilitator_status, ->(status) {
    case status
    when "active" then facilitators_active
    when "inactive" then facilitators_inactive
    when "boomerang" then boomerang_facilitators
    when "formerly_active" then facilitators_formerly_active
    else all
    end }
  scope :subscribed_to_topic, ->(topic_subscription_type_id) {
    joins(:topic_subscriptions)
      .where(topic_subscriptions: { topic_subscription_type_id: topic_subscription_type_id, unsubscribed_at: nil })
      .distinct }
  scope :age_range_names_all, ->(name) {
    return all if name.blank?
    joins(categories: :category_type)
      .where(category_types: { name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE })
      .where("LOWER(categories.name) = ?", name.to_s.strip.downcase)
      .distinct }
  scope :by_role, ->(role) {
    case role
    when "story_author" then story_authors
    when "blog_author" then blog_authors
    when "workshop_author" then workshop_authors
    when "workshop_variation_author" then workshop_variation_authors
    when "workshop_log_author" then workshop_log_authors
    when "sector_leader" then sector_leaders
    else all
    end }
  # People whose membership/current invoice is in the given state.
  scope :membership_active, -> { where(id: Membership.not_cancelled.select(:person_id)) }
  scope :membership_inactive, -> {
    where(id: Membership.select(:person_id))
      .where.not(id: Membership.not_cancelled.select(:person_id)) }
  scope :membership_paid, -> {
    where(id: MembershipInvoice.active_on.paid_in_full.joins(:membership).select("memberships.person_id")) }
  scope :membership_due, -> {
    where(id: MembershipInvoice.active_on.not_paid_in_full.paid_or_within_grace
      .joins(:membership).select("memberships.person_id")) }
  scope :membership_overdue, -> {
    where(id: MembershipInvoice.active_on.overdue.joins(:membership).select("memberships.person_id")) }
  scope :by_membership_status, ->(status) {
    case status
    when "active" then membership_active
    when "inactive" then membership_inactive
    when "paid" then membership_paid
    when "due" then membership_due
    when "overdue" then membership_overdue
    else all
    end }

  ROLE_FILTER_OPTIONS = [
    [ "Story authors", "story_author" ],
    [ "Blog authors", "blog_author" ],
    [ "Workshop authors", "workshop_author" ],
    [ "Workshop variation authors", "workshop_variation_author" ],
    [ "Workshop log authors", "workshop_log_author" ],
    [ "Sector leaders", "sector_leader" ]
  ].freeze

  MEMBERSHIP_STATUS_FILTER_OPTIONS = [
    [ "Active", "active" ],
    [ "Inactive", "inactive" ],
    [ "Paid", "paid" ],
    [ "Due", "due" ],
    [ "Overdue", "overdue" ]
  ].freeze

  FACILITATOR_STATUS_FILTER_OPTIONS = [
    [ "Active", "active" ],
    [ "Inactive", "inactive" ],
    [ "Boomerang (2+ affiliations, 1+ active)", "boomerang" ],
    [ "Formerly active", "formerly_active" ]
  ].freeze

  def self.search_by_params(params)
    results = is_a?(ActiveRecord::Relation) ? self : all
    results = results.search(params[:contact_info]) if params[:contact_info].present?
    results = results.by_role(params[:role]) if params[:role].present?
    results = results.by_facilitator_status(params[:facilitator_status]) if params[:facilitator_status].present?
    results = results.by_membership_status(params[:membership_status]) if params[:membership_status].present?
    results = results.subscribed_to_topic(params[:topic_subscription_type_id]) if params[:topic_subscription_type_id].present?
    results = results.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    results = results.age_range_names_all(params[:age_range_names_all]) if params[:age_range_names_all].present?
    results = results.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    results = results.organization_name(params[:organization_name]) if params[:organization_name].present?
    results = results.organization_id(params[:organization_id]) if params[:organization_id].present?
    results = results.staff_tagged_with(params[:staff_tag_ids]) if params[:staff_tag_ids].present?
    results = results.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    results
  end

  def published?
    profile_is_searchable? && affiliations.active.exists?
  end

  def membership_current?(as_of: Date.current)
    membership_invoices.active_on(as_of).paid_or_within_grace(as_of).exists?
  end

  def sector_list
    sectors.pluck(:name)
  end

  # Virtual checkbox for the admin person form. Presence of a consent timestamp is
  # the source of truth; this lets an admin grant or withdraw consent. Withdrawing
  # clears both the timestamp and its source; granting (when none is on file)
  # stamps the time and records that an admin did it. Re-checking an existing
  # consent leaves the original timestamp/source intact.
  def mailing_list_consented
    mailing_list_consent_at.present?
  end

  def mailing_list_consented=(value)
    consented = ActiveModel::Type::Boolean.new.cast(value)

    if consented
      return if mailing_list_consent_at.present?
      self.mailing_list_consent_at = Time.current
      self.mailing_list_consent_source = "Admin update"
    else
      self.mailing_list_consent_at = nil
      self.mailing_list_consent_source = nil
    end
  end

  # Drives the people index and the profile header. Author credits pass an explicit
  # preference (the record's own, which outranks the profile) through `name_for`.
  def name
    name_for(display_name_preference)
  end

  # Formats the name by a given preference rather than the profile's, so a record
  # that stored its own credit preference can win over the profile.
  def name_for(preference)
    case preference
    when "first_name_last_initial"
      initial = last_name&.first
      initial.present? ? "#{first_name} #{initial}." : first_name.to_s
    when "first_name_only"
      first_name
    when "last_name_only"
      last_name
    else # full_name — the default, and the fallback for any unknown value
      full_name
    end
  end

  # Anonymity is a separate axis from the name format: it suppresses author credits
  # without affecting how they're listed on the people index.
  def effective_author_credit_preference
    return "anonymous" if anonymous_contributions?
    display_name_preference.presence || "full_name"
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  # Distinct professional-license types (e.g. "LMFT, LCSW"), shown as a credential
  # suffix after the person's name on their profile (replaces the old free-text
  # credentials field). Nil when no licensed types are on file.
  def license_credentials
    professional_licenses.filter_map { |license| license.kind.presence&.strip }.uniq.join(", ").presence
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

  # The primary active phone, or the first one on file. Reads the loaded
  # contact_methods when a caller has preloaded it (rosters, CSV exports), so a
  # page or export of people doesn't pay a query per row.
  def phone_number
    phones =
      if contact_methods.loaded?
        contact_methods.to_a.select { |method| method.phone? && !method.inactive? }
      else
        contact_methods.where(kind: :phone, inactive: false).to_a
      end

    (phones.find(&:primary?) || phones.first)&.value
  end

  def has_liasion_position_for?(organization_id)
    affiliations.where(organization_id: organization_id, title: Affiliation::LIAISON_TITLE).exists?
  end

  def primary_organization
    affiliations
      .active
      .order(updated_at: :desc)
      .first&.organization
  end

  # The organization a person facilitates for — the org on their (active, most
  # recent) facilitator affiliation. This is the "program" a scholarship serves.
  # Falls back to any facilitator affiliation when none is currently active.
  # Selects in memory so a preloaded affiliations association (the scholarship
  # index eager-loads it) is reused rather than re-queried per recipient.
  def program_organization
    facilitator_affiliations = affiliations.select(&:facilitator?)
    active = facilitator_affiliations.select(&:active?).max_by(&:updated_at)
    (active || facilitator_affiliations.max_by(&:updated_at))&.organization
  end

  # Facilitator-training events ("TACs") this person registered for and
  # completed (attended). Drives the training column on the scholarship index.
  # Filters in memory to reuse a preloaded event_registrations → event chain.
  def completed_facilitator_trainings
    event_registrations
      .select { |r| r.status == "attended" && r.event&.facilitator_training? }
      .filter_map(&:event)
      .uniq
  end

  def preferred_email
    user&.email.presence || email.presence || email_2.presence
  end

  # Email the communications box matches notifications against. Uniform accessor
  # so the shared notifications/_communications partial works across records.
  def communications_email
    preferred_email
  end

  remote_searchable_by :first_name, :last_name, :email, :legal_first_name, :email_2

  def remote_search_label
    {
      id: id,
      label: preferred_email.present? ?
        "#{full_name} (#{preferred_email})" :
        full_name
    }
  end

  # Field identifiers whose "Other" free text maps onto the category-backed
  # profile fields shown on the edit page.
  OTHER_WORKSHOP_SETTING_IDENTIFIERS = FormField::AGE_GROUP_FIELD_IDENTIFIERS

  # Free-text "Other" sectors the person typed on registration forms, captured
  # as OtherResponse records (see EventRegistrationServices::PublicRegistration).
  # They can't be Sector records, so they're surfaced beside the sector tags —
  # only while pending or explicitly kept (dismissed/promoted ones drop off).
  def other_sector_responses
    other_responses.sectors.visible.order(:text)
  end

  # Free-text "Other" workshop settings (category-backed fields) from forms.
  def other_workshop_setting_responses
    other_form_responses(OTHER_WORKSHOP_SETTING_IDENTIFIERS)
  end

  # The age-range nested items in category position order for the cocoon chip
  # editor. Reads the same association the form's nested attributes build into, so
  # unsaved picks survive a failed save (and aren't primary-first — starring
  # shouldn't reshuffle them). Display surfaces lead with the primary instead.
  def age_range_items_ordered
    age_range_categorizable_items.sort_by { |item| [ item.category&.position || 0, item.category&.name.to_s ] }
  end

  private

  # Count the in-memory set (not a DB query): nested attributes build the items in
  # one transaction, so a row-level check would see none persisted yet.
  def at_most_one_primary_age_range
    primary_count = age_range_categorizable_items.reject(&:marked_for_destruction?).count(&:is_primary?)
    return if primary_count <= 1

    errors.add(:base, "Only one age range can be marked as primary")
  end

  # Keep one tagging per age-range category. Prefer the persisted row, fold any
  # duplicate's primary flag onto the keeper, and drop the extras (destroy if
  # persisted, otherwise remove from the unsaved set).
  def dedupe_age_range_items
    live = age_range_categorizable_items.reject(&:marked_for_destruction?)
    live.group_by(&:category_id).each_value do |items|
      next if items.size <= 1

      keeper = items.find(&:persisted?) || items.first
      keeper.is_primary = true if items.any?(&:is_primary?)
      (items - [ keeper ]).each do |dup|
        dup.persisted? ? dup.mark_for_destruction : age_range_categorizable_items.delete(dup)
      end
    end
  end

  def other_form_responses(identifiers)
    form_submissions
      .joins(form_answers: :form_field)
      .where(form_fields: { field_identifier: identifiers })
      .pluck("form_answers.submitted_answer")
      .flat_map { |answer| OtherOption.texts(answer) }
      .uniq
  end

  def strip_whitespace
    self.first_name = first_name&.strip
    self.last_name = last_name&.strip
    self.legal_first_name = legal_first_name&.strip
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
  ## Consider adding additional person info to be saved on stripes customer records
  # def stripe_attributes(pay_customer)
  #   {
  #     address: {
  #       city: pay_customer.owner.city,
  #       country: pay_customer.owner.country
  #     },
  #     metadata: {
  #       pay_customer_id: pay_customer.id,
  #       user_id: id # or pay_customer.owner_id
  #     }
  #   }
  # end
end
