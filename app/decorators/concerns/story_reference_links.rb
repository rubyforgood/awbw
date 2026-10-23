# Workshop and organization links shared by the story and story idea decorators.
# Each link shows only when the viewer may open its target; otherwise its name is plain text.
module StoryReferenceLinks
  extend ActiveSupport::Concern

  def workshop_links(link_class: "hover:underline")
    parts = workshop_references.map { |reference| workshop_reference_link(reference, link_class) }.compact
    h.safe_join(parts, " / ") if parts.any?
  end

  def workshop_reference_count
    workshop_references.size
  end

  def organization_link(link_class: "hover:underline")
    return if organization.nil?
    return organization.name unless h.allowed_to?(:show?, organization)
    h.link_to(organization.name, h.organization_path(organization), class: link_class, data: { turbo_frame: "_top" })
  end

  private

  def workshop_reference_label(reference)
    reference.external_workshop_title.presence || reference.workshop&.title
  end

  def workshop_reference_link(reference, link_class)
    workshop = reference.workshop
    text = workshop_reference_label(reference)
    return h.html_escape(text) if workshop.nil?

    workshop_link(workshop, link_class, text:)
  end

  def workshop_link(workshop, link_class, text: workshop.title)
    return h.html_escape(text) unless h.allowed_to?(:show?, workshop)
    h.link_to(text, h.workshop_path(workshop), class: link_class, data: { turbo_frame: "_top" })
  end
end
