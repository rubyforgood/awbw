module TimelineRouter
  def self.targets_for(subject)
    return [ subject ] if subject.is_a?(HasTimeline)

    []
  end
end
