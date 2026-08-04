class OrganizationDecorator < ApplicationDecorator
  # Canonical program status => DomainTheme colour key. Keeping these as theme
  # keys means the palette lives in DomainTheme::COLORS (green / blue / purple —
  # amber is reserved for warnings) rather than hard-coded utilities here.
  PROGRAM_STATUS_THEME_KEYS = {
    new: :program_new,
    ongoing: :program_ongoing,
    reinstated: :program_reinstated
  }.freeze

  # Normalize either the :new/:ongoing/:reinstated symbol (EventDashboard / index
  # controller) or the "New"/"Ongoing"/"Reinstate" string (Organization#program_status)
  # to the canonical symbol; nil when blank or unrecognized.
  def self.program_status_key(status)
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

    h.content_tag(:span, key.to_s.first.upcase,
                  title: key.to_s.titleize,
                  class: "inline-flex shrink-0 items-center justify-center w-5 h-5 rounded-full border text-xs font-semibold #{self.class.program_status_classes(status)}")
  end

  # The org form's type dropdown offers Organization::AGENCY_TYPES. A record may
  # still hold a value that is no longer offered (e.g. the pre-rename legacy label
  # "Other (please specify below)"); rendered as-is the select finds no match and
  # an untouched save would silently reclassify the org as the first option. Fold
  # any unrecognized non-blank value into the catch-all "Other". Blank stays blank.
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
                  class: "fa-solid fa-star shrink-0 text-amber-400",
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

  def facilitator_since_date
    @facilitator_since_date ||= affiliations.facilitators.minimum(:start_date)
  end

  def facilitation_end_date
    facilitator_affiliations = affiliations.facilitators
    return nil if facilitator_affiliations.active.exists?
    facilitator_affiliations.maximum(:end_date)
  end

  # In-memory program status (:new / :ongoing / :reinstated) for this org as it
  # stood on a given date — the same New/Ongoing/Reinstate classification used in
  # event context (Organization#facilitator_status_on), computed from the
  # already-loaded affiliations so a profile can classify many events without an
  # N+1. No facilitator affiliation starting before the date => :new; an earlier
  # one still active on the date => :ongoing; all earlier ones ended => :reinstated.
  def facilitator_status_as_of(date)
    reference = date&.to_date || Date.current
    earlier = affiliations.select { |affiliation| affiliation.facilitator? && affiliation.start_date.present? && affiliation.start_date.to_date < reference }
    return :new if earlier.empty?

    active = earlier.any? { |affiliation| affiliation.end_date.nil? || affiliation.end_date.to_date >= reference }
    active ? :ongoing : :reinstated
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
