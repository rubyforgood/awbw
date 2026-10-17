module DataHealth
  # Stories that don't point at a specific workshop: no workshop linked at all, or
  # linked only to a generic "Adult/Children's Windows Workshop" stand-in.
  class StoriesWithoutWorkshop < Check
    PLACEHOLDER_TITLE = /\A(adults?|child|children|kids?)['’]?s?['’]?\s+windows\s+workshops?\z/i

    def title = "Stories without a specific workshop"

    def explanation
      "Each story should credit the workshop it came from. These link none, or only a generic " \
      "Adult or Children's Windows Workshop, so they don't show up on any workshop's page."
    end

    def scope
      specific = StoryWorkshop.where("stories_workshops.story_id = stories.id")
        .where.not(workshop_id: nil)
        .where.not(workshop_id: placeholder_workshop_ids)

      Story.where.not(specific.arel.exists).includes(story_workshops: :workshop).order(:title)
    end

    def describe(story)
      linked = story.story_workshops.filter_map { |link| link.workshop&.title || link.external_workshop_title }
      "#{story.title} — #{linked.any? ? "linked only to #{linked.to_sentence}" : 'no workshop linked'}"
    end

    def path_for(story) = edit_story_path(story)

    private

    def placeholder_workshop_ids
      Workshop.where("LOWER(workshops.title) LIKE ?", "%windows workshop%")
        .pluck(:id, :title)
        .filter_map { |id, title| id if title.to_s.strip.match?(PLACEHOLDER_TITLE) }
    end
  end
end
