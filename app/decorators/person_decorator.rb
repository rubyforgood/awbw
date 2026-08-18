class PersonDecorator < ApplicationDecorator
  def title
    "#{first_name} #{last_name}"
  end

  def detail(length: nil)
    text = affiliations.active.map { |affiliation| "#{affiliation.title}, #{affiliation.organization.name}" }.join(", ")
    length ? text&.truncate(length) : text
  end

  def default_display_image
    "missing.png"
  end

  def primary_asset
    avatar
  end

  def pronouns_display
    profile_show_pronouns ? pronouns : nil
  end

  def default_display_image
    return avatar if respond_to?(:avatar) && avatar&.attached?
    "missing.png"
  end

  def affiliation_end_date
    return nil if affiliations.active.exists?
    affiliations.maximum(:end_date)
  end

  # Org names where this person is currently an active facilitator. Filters the
  # affiliations in Ruby (rather than re-querying via the .facilitators.active
  # scopes) so list pages that preload `affiliations: :organization` pay no
  # per-row query cost.
  def active_facilitator_organization_names
    affiliations
      .select { |affiliation| affiliation.facilitator? && affiliation.active? }
      .filter_map { |affiliation| affiliation.organization&.name }
      .uniq
      .sort
  end

  def facilitation_end_date
    facilitator_affiliations = affiliations.facilitators
    return nil if facilitator_affiliations.active.exists?
    facilitator_affiliations.maximum(:end_date)
  end

  def member_since_year
    facilitator_since_date&.year
  end

  def member_since_earlier_than_facilitator_affiliations?
    earliest_facilitator = affiliations.facilitators.minimum(:start_date)
    member_since.present? && earliest_facilitator.present? && member_since.beginning_of_month < earliest_facilitator.beginning_of_month
  end

  def member_since_earlier_than_all_affiliations?
    earliest = affiliations.minimum(:start_date)
    member_since.present? && earliest.present? && member_since.beginning_of_month < earliest.beginning_of_month
  end

  def member_since_differs_from_facilitator_affiliations?
    earliest_facilitator = affiliations.facilitators.minimum(:start_date)
    member_since.present? && earliest_facilitator.present? && member_since.beginning_of_month != earliest_facilitator.beginning_of_month
  end

  def member_since_differs_from_all_affiliations?
    earliest = affiliations.minimum(:start_date)
    member_since.present? && earliest.present? && member_since.beginning_of_month != earliest.beginning_of_month
  end

  def badges
    @badges ||= compute_badges
  end

  def facilitator_since_date
    @facilitator_since_date ||= begin
      facilitator_affiliations = affiliations.facilitators
      facilitator_affiliations.minimum(:start_date) || member_since
    end
  end

  def affiliated_since_date
    # Compute in Ruby from the (eager-loaded) association so list pages that
    # preload affiliations don't fire a MIN(start_date) query per row.
    # `.minimum` would ignore the loaded records and hit the DB every time.
    @affiliated_since_date ||= affiliations.filter_map(&:start_date).min
  end

  # The server-rendered twin of affiliation_dates_controller#updateDisplay, which
  # replaces this content as the person form's affiliation rows are edited.
  def affiliated_since_range
    date_range_display(affiliated_since_date, affiliation_end_date, ended_title: "No active affiliations")
  end

  def facilitator_since_range
    date_range_display(facilitator_since_date, facilitation_end_date, ended_title: "No active facilitator affiliations")
  end

  private

  def compute_badges
    earliest = facilitator_since_date
    years = earliest ? (Time.zone.now.year - earliest.year) : nil
    badges = []
    badges << badge("Legacy Facilitator (10+ years)", :legacy_facilitator) if years && years >= 10
    badges << badge("Seasoned Facilitator (3-10 years)", :seasoned_facilitator) if years && years.between?(3, 9)
    badges << badge("New Facilitator (<3 years)", :new_facilitator) if years && years < 3
    badges << badge("Spotlighted Facilitator", :spotlighted_facilitator) if stories_as_spotlighted_facilitator.any?
    badges << badge("Events Attended", :events) if user&.events&.any?
    badges << badge("Workshop Author", :workshops) if user&.workshops&.any?
    badges << badge("Workshop Variation Author", :workshop_variations) if user&.workshop_variations_as_creator&.any?
    badges << badge("Story Author", :stories) if user&.stories_as_creator&.any?
    badges << badge("Sector Leader", :sectors) if sectorable_items.where(is_leader: true).any?
    badges << badge("Blog Contributor", :blog_contributor) if blog_contributor?
    if affiliated_since_date.present? && affiliated_since_date != facilitator_since_date
      badges << badge("Affiliated since #{affiliated_since_date.strftime('%B %Y')}", :affiliated_person)
    end
    badges
  end

  def date_range_display(since, ended, ended_title:)
    parts = []
    parts << h.content_tag(:i, "", class: "fa-solid fa-circle-xmark text-red-400 mr-1", title: ended_title) if ended
    parts << (since&.strftime("%b %Y") || "—")
    parts << " – #{ended.strftime('%b %Y')}" if ended
    h.safe_join(parts)
  end

  def badge(label, key)
    {
      label: label,
      bg: DomainTheme.bg_class_for(key, intensity: 100),
      text: DomainTheme.text_class_for(key),
      border: DomainTheme.border_class_for(key)
    }
  end
end
