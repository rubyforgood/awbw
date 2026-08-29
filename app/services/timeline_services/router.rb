module TimelineServices
  module Router
    def self.targets_for(subject)
      case subject
      when Comment
        case subject.commentable
        when Person then [ subject.commentable ].compact
        when User then [ subject.commentable.person ].compact
        when EventRegistration then [ subject.commentable, subject.commentable.registrant ].compact.uniq
        when ContinuingEducationRegistration then [ subject.commentable.event_registration&.registrant ].compact
        when Scholarship then [ subject.commentable.recipient ].compact
        when TopicSubscription then [ subject.commentable.person ].compact
        when Organization then [ subject.commentable ].compact
        else []
        end
      when Notification
        return [] unless subject.noticeable.present?
        [ subject.noticeable ].compact
      when Scholarship
        [ subject.recipient, subject.allocation&.allocatable ].compact.uniq
      when ContinuingEducationRegistration
        [ subject.event_registration&.registrant, subject.event_registration ].compact.uniq
      when FormSubmission
        targets = [ subject.person ].compact
        if subject.event_id.present?
          registration = EventRegistration.find_by(event_id: subject.event_id, registrant_id: subject.person_id)
          targets << registration if registration
        end
        targets.uniq
      when Affiliation
        [ subject.person, subject.organization ].compact.uniq
      when Address
        [ subject.addressable ].compact
      when ContactMethod
        [ subject.contactable ].compact
      when ProfessionalLicense
        [ subject.person ].compact
      when StaffTagging
        [ subject.staff_taggable ].compact
      when SectorableItem
        [ subject.sectorable ].compact
      when CategorizableItem
        [ subject.categorizable ].compact
      else
        return [ subject ] if subject.is_a?(HasTimeline)

        []
      end
    end
  end
end
