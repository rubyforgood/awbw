module Analytics
  # Strips who did it from the activity events a form submission, its answers, and
  # their uploads left behind, for a submission that has gone anonymous: the user,
  # the visit (which carries the user), and any person/creator ids in the recorded
  # attributes or changes. The events stay, so the record's own history still reads.
  class AnonymizeSubmissionEvents
    IDENTIFYING_KEYS = %w[person_id created_by_id updated_by_id].freeze
    TRACKED_SECTIONS = %w[attributes changes].freeze

    def self.call(submission)
      new(submission).call
    end

    def initialize(submission)
      @submission = submission
    end

    def call
      events.find_each do |event|
        event.update_columns(user_id: nil, visit_id: nil, properties: scrubbed(event.properties))
      end
    end

    private

    def events
      answer_ids = @submission.form_answers.select(:id)
      Ahoy::Event.where(resource_type: "FormSubmission", resource_id: @submission.id)
        .or(Ahoy::Event.where(resource_type: "FormAnswer", resource_id: answer_ids))
        .or(Ahoy::Event.where(resource_type: "Asset", resource_id: Asset.where(owner_type: "FormAnswer", owner_id: answer_ids).select(:id)))
    end

    def scrubbed(properties)
      properties = (properties || {}).deep_dup
      TRACKED_SECTIONS.each do |section|
        properties[section] = properties[section].except(*IDENTIFYING_KEYS) if properties[section].is_a?(Hash)
      end
      properties
    end
  end
end
