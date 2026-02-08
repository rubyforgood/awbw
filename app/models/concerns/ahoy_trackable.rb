module AhoyTrackable
  extend ActiveSupport::Concern

  included do
    after_create  -> { track_lifecycle_event("create") }
    after_update  -> { track_update_event }
    after_destroy -> { track_lifecycle_event("destroy") }
  end

  private

  def devise_only_changes?(changes)
    auth_fields = %w[
      current_sign_in_at
      last_sign_in_at
      current_sign_in_ip
      last_sign_in_ip
      sign_in_count
      remember_created_at
    ]

    (changes.keys - auth_fields).empty?
  end

  def track_update_event
    return if previously_new_record? # Skip the fake "update" that happens right after create

    changes = previous_changes.except("updated_at", "created_at")
    return if changes.empty?
    return if devise_only_changes?(changes)

    track_lifecycle_event("update")
  end

  def track_lifecycle_event(action)
    return unless Current.user
    return if self.class.name.start_with?("Ahoy::")
    return if self.class.name.in?(%w[Notification ActiveStorage::Attachment ActiveStorage::Blob])

    # prevent nested tracking loops
    return if Thread.current[:_ahoy_tracking]
    Thread.current[:_ahoy_tracking] = true

    payload = Analytics::EventBuilder.lifecycle(action, self, user: Current.user)
    Analytics::LifecycleBuffer.push(payload)
  rescue => e
    Rails.logger.error "Ahoy lifecycle tracking failed: #{e.message}"
  ensure
    Thread.current[:_ahoy_tracking] = false
  end
end
