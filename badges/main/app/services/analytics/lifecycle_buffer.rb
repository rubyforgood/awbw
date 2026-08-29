# app/services/analytics/lifecycle_buffer.rb
module Analytics
  class LifecycleBuffer
    def self.push(event)
      store << event
    end

    def self.flush(controller)
      return if store.empty?

      store.each do |payload|
        stamp_form_submission(payload)
        controller.ahoy.track(payload[:name], payload[:properties])
      end
    ensure
      store.clear
    end

    # The submission a public form/registration writes is created partway through
    # the request, after many of its lifecycle events have already been buffered,
    # so the id isn't knowable at push time. Stamp it here at flush — by which
    # point the controller has set Current.form_submission_id — so every record
    # the submission touched can be traced back to it.
    def self.stamp_form_submission(payload)
      return unless Current.form_submission_id

      payload[:properties] ||= {}
      payload[:properties][:form_submission_id] ||= Current.form_submission_id
    end

    def self.store
      Thread.current[:_ahoy_lifecycle_events] ||= []
    end
  end
end
