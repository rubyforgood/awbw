class StoryDecorator < ApplicationDecorator
  include ::Linkable
  include ::StoryReferenceLinks

  def detail(length: 50)
    text = rhino_body&.to_plain_text
    length ? text&.truncate(length) : text
  end

  def external_url
    object.website_url
  end

  def workshop_title
    story_workshops.map { |sw| workshop_reference_label(sw) }.compact_blank.presence&.join(" / ")
  end

  def spotlighted_facilitator_label
    return unless spotlighted_facilitator

    [ "Spotlighted facilitator", spotlighted_facilitator.name.presence ].compact.join(": ")
  end

  def spotlighted_facilitator_link(link_class: "hover:underline")
    person = spotlighted_facilitator
    return if person.nil?
    return person.name unless h.allowed_to?(:show?, person)
    h.link_to(person.name, h.person_path(person), class: link_class, data: { turbo_frame: "_top" })
  end

  def showcase_path(**params)
    h.allowed_to?(:show?, object, with: StorySharePolicy) ? h.story_share_path(object, **params) : h.story_path(object)
  end

  private

  def workshop_references
    story_workshops
  end
end
