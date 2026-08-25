module TimelineServices
  module RecordEvent
    ACTOR_LABELS_BY_SOURCE = {
      "public_registration" => "Registration",
      "public_form" => "Form Submission"
    }.freeze

    def self.call(subject:, action:, actor: Current.user, snapshot: {}, also_log: [])
      return if suppressed?

      TimelineEvent.transaction do
        event = TimelineEvent.create!(
          subject: subject,
          actor: actor,
          action: action.to_s,
          snapshot: build_snapshot(subject, actor, snapshot)
        )
        targets_for(subject, also_log).each do |target|
          event.timeline_entries.create!(owner: target)
        end
        event
      end
    end

    def self.suppress
      previous = Thread.current[:_timeline_suppressed]
      Thread.current[:_timeline_suppressed] = true
      yield
    ensure
      Thread.current[:_timeline_suppressed] = previous
    end

    def self.suppressed?
      Thread.current[:_timeline_suppressed] == true
    end

    def self.build_snapshot(subject, actor, snapshot)
      generated = { "changes" => {} }
      if actor.nil? && Current.source
        generated["actor_label"] = ACTOR_LABELS_BY_SOURCE[Current.source]
      end
      generated["label"] = subject.timeline_label if subject.respond_to?(:timeline_label)
      generated.merge(snapshot)
    end

    def self.targets_for(subject, also_log)
      targets = (TimelineServices::Router.targets_for(subject) + Array(also_log)).compact.uniq
      raise ArgumentError, "no timeline target for #{subject.class.name}" if targets.empty?

      targets
    end
  end
end
