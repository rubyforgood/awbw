module StoryServices
  # Notifies the original story idea submitter, by email, when their idea has
  # been promoted into a published story. Safe to call on every story save:
  # it no-ops unless the story came from an idea, is published, and the author
  # has not already been notified for this story.
  class NotifyIdeaAuthorOfPublication
    def self.call(story)
      new(story).call
    end

    def initialize(story)
      @story = story
    end

    def call
      return unless story.story_idea
      return unless story.published?

      author = story.story_idea.created_by
      return if author&.email.blank?
      return if already_notified?

      NotificationServices::CreateNotification.call(
        noticeable: story,
        kind: :story_published,
        recipient_role: :person,
        recipient_email: author.email,
        notification_type: 0
      )
    end

    private

    attr_reader :story

    def already_notified?
      Notification.exists?(noticeable: story, kind: "story_published")
    end
  end
end
