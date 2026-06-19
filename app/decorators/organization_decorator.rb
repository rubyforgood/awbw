class OrganizationDecorator < ApplicationDecorator
  # Tailwind classes for an organization's AWBW program status, keyed by the
  # canonical :new/:ongoing/:reinstated symbol. Single source of truth for these
  # colors — the badge below and the event background dashboard both read it.
  # Yellow (not amber) for reinstated, since amber signals a warning in our UI.
  PROGRAM_STATUS_CLASSES = {
    new: "bg-green-100 text-green-700 border-green-200",
    ongoing: "bg-blue-100 text-blue-700 border-blue-200",
    reinstated: "bg-yellow-100 text-yellow-700 border-yellow-200"
  }.freeze

  # Normalize either the :new/:ongoing/:reinstated symbol (EventDashboard / index
  # controller) or the "New"/"Ongoing"/"Reinstate" string (Organization#program_status)
  # to the canonical symbol; nil when blank or unrecognized.
  def self.program_status_key(status)
    return if status.blank?

    key = status.to_s.downcase.start_with?("reinstat") ? :reinstated : status.to_s.downcase.to_sym
    key if PROGRAM_STATUS_CLASSES.key?(key)
  end

  def self.program_status_classes(status)
    PROGRAM_STATUS_CLASSES[program_status_key(status)]
  end

  # Compact single-letter program-status badge (N / O / R) with the full label as
  # a tooltip. Defaults to this org's own #program_status; pass a precomputed
  # status on list pages (index / dashboard) to avoid loading affiliations per row.
  def program_status_badge(status = object.program_status)
    key = self.class.program_status_key(status)
    return unless key

    h.content_tag(:span, key.to_s.first.upcase,
                  title: key.to_s.titleize,
                  class: "inline-flex shrink-0 items-center justify-center w-5 h-5 rounded-full border text-xs font-semibold #{PROGRAM_STATUS_CLASSES[key]}")
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
    @facilitator_since_date ||= affiliations.where("title LIKE ?", "%Facilitator%").minimum(:start_date)
  end

  def facilitation_end_date
    facilitator_affiliations = affiliations.where("title LIKE ?", "%Facilitator%")
    return nil if facilitator_affiliations.active.exists?
    facilitator_affiliations.maximum(:end_date)
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
