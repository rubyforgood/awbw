class ProfessionalLicense < ApplicationRecord
  include OutsideUsaTypeable

  has_paper_trail

  typed_outside_usa :issuing_state

  belongs_to :person
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :continuing_education_registrations, dependent: :destroy
  has_many :profile_change_requests, dependent: :nullify

  # Deleting a license cascades to its CE registrations (and their allocations),
  # so refuse to remove one that has any CE registration at all — regardless of
  # whether those registrations carry payments. prepend so this runs before the
  # dependent: :destroy cascade below clears those registrations.
  before_destroy :prevent_destroy_with_ce, prepend: true
  before_validation :default_issuing_country
  before_validation :split_kind_out_of_number

  # California BBS license types, recognized when typed in front of the number ("LMFT 42111").
  TYPED_KINDS = %w[LMFT LCSW LPCC LEP AMFT ACSW APCC].freeze
  TYPED_KIND_PATTERN = /\A(#{TYPED_KINDS.join("|")})(?=[\s#:.\-\d])[\s#:.\-]*(\S.*)\z/i

  # A license is identified by its kind + number, so the same number under two
  # different kinds is allowed; only a duplicate (kind, number) pair is rejected.
  validates :number, uniqueness: { scope: [ :person_id, :kind ] }, allow_nil: true

  scope :of_kind, ->(kind) { where(kind: kind) }
  scope :expired, -> { where.not(expires_on: nil).where("expires_on < ?", Date.current) }
  scope :not_expired, -> { where("expires_on IS NULL OR expires_on >= ?", Date.current) }
  # Issued in, or held by someone with a live address in, a state or province (a US
  # state by name or code), a country, or a city starting with the text.
  scope :located_in, ->(place) {
    place = place.to_s.strip
    state = AddressTranslation.new.state(place, country: nil)
    holders = Address.active.where(addressable_type: "Person")
      .where("addresses.state = :state OR addresses.country = :place OR addresses.city LIKE :city",
             state:, place:, city: "#{sanitize_sql_like(place)}%")
      .select(:addressable_id)
    where("professional_licenses.issuing_state = :state OR professional_licenses.issuing_country = :place", state:, place:)
      .or(where(person_id: holders))
  }

  # Drives the admin index filters (registrant, kind, location, expiry status). The
  # registrant filter is a free-text search over the holder's name (incl. legal
  # first name) and email, reusing Person's remote-search columns.
  def self.search_by_params(params)
    results = all
    if params[:person_query].present?
      results = results.where(person: Person.remote_search(params[:person_query]).reorder(nil))
    end
    results = results.of_kind(params[:kind]) if params[:kind].present?
    results = results.located_in(params[:location]) if params[:location].present?
    results = results.expired if params[:expired] == "yes"
    results = results.not_expired if params[:expired] == "no"
    results
  end

  # Find the person's license for this type + number, or create it. Licenses are
  # identified by (kind, number), so an opt-in without either on file resolves to
  # the person's single placeholder license (both nil) rather than spawning
  # duplicate placeholders.
  def self.find_or_create_for(person:, number: nil, kind: nil)
    kind, number = split_kind_from_number(kind: kind, number: number)
    find_or_create_by(person: person, number: number.presence, kind: kind.presence)
  end

  # [kind, number], with a known license type typed in front of the number moved
  # into the kind. Left as given when the kind is already set.
  def self.split_kind_from_number(kind:, number:)
    return [ kind, number ] if kind.present?

    match = number.to_s.strip.match(TYPED_KIND_PATTERN)
    match ? [ match[1].upcase, match[2] ] : [ kind, number ]
  end

  # Completeness: have we recorded the actual license number yet?
  def number_known?
    number.present?
  end

  # Validity: a license with a past expiration is expired. Unknown when no
  # expiration is on file.
  def expired?
    expires_on.present? && expires_on.past?
  end

  def name
    [ kind, number ].compact_blank.join(" ").presence || "License (number pending)"
  end

  # True when this license has no CE registrations and so can be deleted without
  # cascading away CE history — used to gate the remove control on the person edit
  # form. Once any CE registration exists (paid or not), the license is permanent.
  def removable?
    continuing_education_registrations.none?
  end

  # Has this license been used for CE credit? Drives edit gating: a license tied to
  # any CE registration is locked to admins (see ProfessionalLicensePolicy).
  def used_for_ce?
    continuing_education_registrations.exists?
  end

  private

  # A US state is a US license; the country only means something beside a state outside the USA.
  def default_issuing_country
    self.issuing_country = Address::DEFAULT_COUNTRY if issuing_state.in?(Address::US_STATE_ABBREVIATIONS)
  end

  def split_kind_out_of_number
    self.kind, self.number = self.class.split_kind_from_number(kind: kind, number: number)
  end

  def prevent_destroy_with_ce
    return if removable?

    errors.add(:base, "Can't remove a license with CE registrations.")
    throw :abort
  end
end
