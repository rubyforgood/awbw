module TimelineTracked
  extend ActiveSupport::Concern

  SENSITIVE_ATTRIBUTE_PATTERN = /password|token|secret|key|digest|salt|otp/i

  included do
    after_create -> { record_timeline_event("created") }
    after_update -> { record_timeline_event("updated") if timeline_changes.any? }
  end

  private

  def record_timeline_event(action)
    TimelineServices::RecordEvent.call(
      subject: self,
      action: action,
      snapshot: { "changes" => timeline_changes }
    )
  end

  def timeline_changes
    saved_changes.except("id", "created_at", "updated_at", "created_by_id", "updated_by_id")
                 .reject { |attribute, _| attribute.match?(SENSITIVE_ATTRIBUTE_PATTERN) }
                 .reject { |_, (old_value, new_value)| old_value.to_s == new_value.to_s }
                 .transform_values { |(old_value, new_value)| [ old_value.to_s, new_value.to_s ] }
  end
end
