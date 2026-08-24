module TimelineServices
  module Router
    def self.targets_for(subject)
      case subject
      when Comment
        case subject.commentable
        when Person then [ subject.commentable ].compact
        when User then [ subject.commentable.person ].compact
        when EventRegistration then [ subject.commentable.registrant ].compact
        when ContinuingEducationRegistration then [ subject.commentable.event_registration&.registrant ].compact
        when Scholarship then [ subject.commentable.recipient ].compact
        when TopicSubscription then [ subject.commentable.person ].compact
        else []
        end
      else
        return [ subject ] if subject.is_a?(HasTimeline)

        []
      end
    end
  end
end
