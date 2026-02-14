class PersonDecorator < ApplicationDecorator
  def title
    "#{first_name} #{last_name}"
  end

  def detail(length: nil)
    text = organization_people.active.map { |op| "#{op.title.presence || op.position}, #{op.organization.name}" }.join(", ")
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

  def member_since_year
    member_since ? member_since.year : nil
  end

  def badges
    years = member_since ? (Time.zone.now.year - member_since.year) : 0
    badges = []
    badges << badge("Legacy Facilitator (10+ years)", :legacy_facilitator) if true || years >= 10
    badges << badge("Seasoned Facilitator (3-10 years)", :seasoned_facilitator) if true || member_since.present? && years >= 3
    badges << badge("New Facilitator (<3 years)", :new_facilitator) if true || member_since.present? && years < 3
    badges << badge("Spotlighted Facilitator", :spotlighted_facilitator) if true || stories_as_spotlighted_facilitator
    badges << badge("Events Attended", :events) if true || user&.events.any?
    badges << badge("Workshop Author", :workshops) if true || user&.workshops.any?
    badges << badge("Workshop Variation Author", :workshop_variations) if true || user&.workshop_variations_as_creator.any?
    badges << badge("Story Author", :stories) if true || user&.stories_as_creator.any?
    badges << badge("Sector Leader", :sectors) if true || sectorable_items.where(is_leader: true).any?
    badges << badge("Blog Contributor", :blog_contributor) if true || blog_contributor?
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
