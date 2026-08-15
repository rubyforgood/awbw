class ProfessionalLicense < ApplicationRecord
  has_paper_trail

  belongs_to :person
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :continuing_education_registrations, dependent: :destroy

  # Deleting a license cascades to its CE registrations (and their allocations),
  # so refuse to remove one that has any CE registration at all — regardless of
  # whether those registrations carry payments. prepend so this runs before the
  # dependent: :destroy cascade below clears those registrations.
  before_destroy :prevent_destroy_with_ce, prepend: true

  # A license is identified by its kind + number, so the same number under two
  # different kinds is allowed; only a duplicate (kind, number) pair is rejected.
  validates :number, uniqueness: { scope: [ :person_id, :kind ] }, allow_nil: true

  scope :for_person, ->(person_id) { where(person_id: person_id) }
  scope :of_kind, ->(kind) { where(kind: kind) }
  scope :expired, -> { where.not(expires_on: nil).where("expires_on < ?", Date.current) }
  scope :not_expired, -> { where("expires_on IS NULL OR expires_on >= ?", Date.current) }

  # Drives the admin index filters (registrant, kind, expiry status).
  def self.search_by_params(params)
    results = all
    results = results.for_person(params[:person_id]) if params[:person_id].present?
    results = results.of_kind(params[:kind]) if params[:kind].present?
    results = results.expired if params[:expired] == "yes"
    results = results.not_expired if params[:expired] == "no"
    results
  end

  # Find the person's license for this type + number, or create it. Licenses are
  # identified by (kind, number), so an opt-in without either on file resolves to
  # the person's single placeholder license (both nil) rather than spawning
  # duplicate placeholders.
  def self.find_or_create_for(person:, number: nil, kind: nil)
    find_or_create_by(person: person, number: number.presence, kind: kind.presence)
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

  def prevent_destroy_with_ce
    return if removable?

    errors.add(:base, "Can't remove a license with CE registrations.")
    throw :abort
  end
end
