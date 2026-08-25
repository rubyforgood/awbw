module Timelineable
  extend ActiveSupport::Concern

  SENSITIVE_ATTRIBUTE_PATTERN = /password|token|secret|key|digest|salt|otp/i

  included do
    after_create -> { record_timeline_event("created") }
    after_update -> { record_timeline_event("updated") if timeline_changes.any? }
  end

  def record_timeline_event(action)
    TimelineServices::RecordEvent.call(
      subject: self,
      action: action,
      snapshot: { "changes" => timeline_changes },
      also_log: timeline_also_log
    )
  end

  def timeline_also_log
    []
  end

  def timeline_changes
    saved_changes.except("id", "created_at", "updated_at", "created_by_id", "updated_by_id", "slug")
                 .reject { |attribute, _| attribute.match?(SENSITIVE_ATTRIBUTE_PATTERN) }
                 .transform_values { |(old_value, new_value)| [ old_value.to_s, new_value.to_s ] }
  end

  def timeline_label
    model_name.human
  end

  def timeline_renderer_class
    ApplicationTimelineRenderer
  end

  private
end
