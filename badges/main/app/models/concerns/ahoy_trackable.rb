module AhoyTrackable
  extend ActiveSupport::Concern

  included do
    after_create  -> { track_lifecycle_event("create") }
    after_update  -> { track_update_event }
    after_destroy -> { track_lifecycle_event("destroy") }
  end

  private

  def track_update_event
    # Skip the fake "update" that happens right after create
    return if previously_new_record?

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
