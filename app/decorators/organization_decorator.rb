class OrganizationDecorator < ApplicationDecorator
  # Canonical program status => DomainTheme colour key. Keeping these as theme
  # keys means the palette lives in DomainTheme::COLORS (green / blue / purple —
  # amber is reserved for warnings) rather than hard-coded utilities here.
  PROGRAM_STATUS_THEME_KEYS = {
    new: :program_new,
    ongoing: :program_ongoing,
    reinstated: :program_reinstated
  }.freeze

  # Normalize a FacilitatorProgramStatus, the :new/:ongoing/:reinstated symbol, or
  # the "New"/"Ongoing"/"Reinstate" string (Organization#program_status) to the
  # canonical symbol; nil when blank or unrecognized.
  def self.program_status_key(status)
    status = status.status if status.respond_to?(:status)
    return if status.blank?

    key = status.to_s.downcase.start_with?("reinstat") ? :reinstated : status.to_s.downcase.to_sym
    key if PROGRAM_STATUS_THEME_KEYS.key?(key)
  end

  # Pill bg/text/border classes for a program status, built from the DomainTheme
  # swatch so the colours stay consistent with the rest of the app.
  def self.program_status_classes(status)
    key = program_status_key(status)
    return unless key

    theme_key = PROGRAM_STATUS_THEME_KEYS[key]
    [
      DomainTheme.bg_class_for(theme_key, intensity: 100),
      DomainTheme.text_class_for(theme_key, intensity: 700),
      DomainTheme.border_class_for(theme_key, intensity: 200)
    ].join(" ")
  end

  # Compact single-letter program-status badge (N / O / R) with the full label as
  # a tooltip. Defaults to this org's own #program_status; pass a precomputed
  # status on list pages (index / dashboard) to avoid loading affiliations per row.
  def program_status_badge(status = object.program_status)
    key = self.class.program_status_key(status)
    return unless key

    # A FacilitatorProgramStatus explains its own verdict (anchor date, what made
    # the program active); anything else can only name it.
    h.content_tag(:span, key.to_s.first.upcase,
                  title: status.respond_to?(:explanation) ? status.explanation : key.to_s.titleize,
                  class: "inline-flex shrink-0 items-center justify-center w-5 h-5 rounded-full border text-xs font-semibold #{self.class.program_status_classes(status)}")
  end

  # The stored agency_type, folding any value no longer offered (e.g. the legacy
  # "Other (please specify below)") into "Other" so the select can't silently
  # reclassify the org — see AGENCY_TYPES. Blank stays blank.
  def agency_type_option
    return object.agency_type if object.agency_type.blank?
    return object.agency_type if Organization::AGENCY_TYPES.include?(object.agency_type)

    Organization::AGENCY_TYPE_OTHER
  end

  # Star marking a high-profile organization, shown next to the org name on list
  # pages (event dashboard, background reporting). Nil for ordinary orgs so it
  # renders nothing.
  def high_profile_icon
    return unless object.high_profile?

    h.content_tag(:i, "",
                  class: "fa-solid fa-gem shrink-0 text-purple-600",
                  title: "High-profile organization",
                  "aria-hidden": true)
  end

  def detail(length: nil)
    length ? description&.truncate(length) : description
  end

  def default_display_image
    return logo if respond_to?(:logo) && logo&.attached?
    "theme_default.png"
  end

  def title
    name
  end

  def affiliated_since_date
    @affiliated_since_date ||= affiliations.minimum(:start_date)
  end

  def affiliation_end_date
    return nil if affiliations.active.exists?
    affiliations.maximum(:end_date)
  end

  # "Affiliated since": affiliation history as merged year-based periods (see
  # AffiliationPeriods), falling back to the org's start_date, then blank. Pass
  # preloaded affiliations on list pages to avoid an N+1.
  def affiliated_since_display(affiliations = object.affiliations)
    AffiliationPeriods.label(affiliations) || object.start_date&.strftime("%b %Y") || ""
  end

  # "Art program since": facilitator-affiliation history as merged periods (see
  # AffiliationPeriods) at month precision — the exact start/lapse month is the
  # point. Blank when the org has never facilitated.
  def program_since_display(affiliations = object.affiliations)
    AffiliationPeriods.label(affiliations.select(&:facilitator?), precision: :month) || ""
  end

  ORG_STATUS_BUCKET_LABELS = {
    active: "Active", formerly_active: "Formerly active", never_active: "Never active"
  }.freeze
  ORG_STATUS_BUCKET_THEMES = {
    active: :org_active, formerly_active: :org_formerly_active, never_active: :org_never_active
  }.freeze

  # The org's program-status bucket (:active / :formerly_active / :never_active),
  # derived purely from facilitator affiliations: an active one => :active, only
  # ended ones => :formerly_active, none at all => :never_active. The stored
  # organization_status never feeds into this (see ADR-0001 D3).
  def organization_status_bucket
    facilitators = object.affiliations.select(&:facilitator?)
    return :never_active if facilitators.none?

    facilitators.any?(&:active?) ? :active : :formerly_active
  end

  # The bucket the stored (legacy) OrganizationStatus would imply. Not used to
  # decide the org's status — only to flag on the edit form where the legacy
  # column disagrees with the affiliations.
  def stored_status_bucket
    OrganizationStatus.program_bucket(object.organization_status&.name)
  end

  # True when the legacy OrganizationStatus column contradicts what the org's
  # facilitator affiliations say — e.g. a stored "Active" on an org that has never
  # had a facilitator affiliation. Surfaced as a warning on the edit form.
  def legacy_status_mismatch?
    organization_status_bucket != stored_status_bucket
  end

  def organization_status_label
    ORG_STATUS_BUCKET_LABELS.fetch(organization_status_bucket)
  end

  # Pill classes for a given program-status bucket, built from the DomainTheme
  # swatch so the colours stay consistent with the rest of the app.
  def self.status_classes_for_bucket(bucket)
    theme_key = ORG_STATUS_BUCKET_THEMES.fetch(bucket)
    [
      DomainTheme.bg_class_for(theme_key, intensity: 100),
      DomainTheme.text_class_for(theme_key, intensity: 700),
      DomainTheme.border_class_for(theme_key, intensity: 200)
    ].join(" ")
  end

  # Every bucket's label + pill classes, so the edit form's Stimulus controller
  # can re-render the status chip live as facilitator rows change without
  # hard-coding any theme classes in JS.
  def self.status_bucket_styles
    ORG_STATUS_BUCKET_LABELS.each_key.to_h do |bucket|
      [ bucket, { label: ORG_STATUS_BUCKET_LABELS.fetch(bucket), classes: status_classes_for_bucket(bucket) } ]
    end
  end

  # Pill classes for the org-wide status chip, keyed off the program-status bucket.
  def organization_status_classes
    self.class.status_classes_for_bucket(organization_status_bucket)
  end

  # Rendered org-wide status chip (Active / Formerly active / Never active).
  def organization_status_chip(data: {})
    h.content_tag(:span, organization_status_label,
                  data: data,
                  class: "inline-flex items-center rounded-full text-xs font-medium border px-2.5 py-0.5 #{organization_status_classes}")
  end

  # Index "Program since" chip for admins: the facilitator-period years coloured
  # by the org's status (green Active / orange Formerly active / gray Never
  # active), falling back to the status label when there are no facilitator years.
  def program_since_chip(years = program_since_display)
    h.content_tag(:span, years.presence || organization_status_label,
                  class: "inline-flex items-center rounded-full text-xs font-medium border px-2.5 py-0.5 #{organization_status_classes}")
  end


  # This org's program status as it stood on a given date, as a
  # FacilitatorProgramStatus (verdict + anchor + reasoning for the hover). Reads
  # the already-loaded affiliations, so a profile classifies many events without
  # an N+1. `date` may be a datetime (event.start_date is one).
  def facilitator_status_as_of(date)
    object.facilitator_program_status(as_of: date&.to_date)
  end

  def badges
    earliest = affiliations.minimum(:start_date) || start_date
    years = earliest ? (Time.zone.now.year - earliest.year) : nil
    badges = []
    badges << badge("Legacy Organization (10+ years)", :legacy_facilitator) if years && years >= 10
    badges << badge("Seasoned Organization (3-10 years)", :seasoned_facilitator) if years && years.between?(3, 9)
    badges << badge("New Organization (<3 years)", :new_facilitator) if years && years < 3
    badges << badge("Workshop Author", :workshops) if workshops.any?
    badges << badge("Workshop Logs", :workshop_logs) if workshop_logs.any?
    badges
  end

  private

  def badge(label, key)
    {
      label: label,
      bg: DomainTheme.bg_class_for(key, intensity: 100),
      text: DomainTheme.text_class_for(key),
      border: DomainTheme.border_class_for(key)
    }
  end
end
