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

    # Flush for work that runs outside a request — a rake task, a job, the
    # console. An event belongs to a visit, so the run gets one of its own and
    # the whole batch stays groupable on the admin activity page; `label` is what
    # that page shows for it. Callers inside a controller leave flushing to it.
    def self.flush_without_request(label:)
      return if store.empty?

      visit = create_batch_visit(label)
      store.each do |payload|
        stamp_form_submission(payload)
        Ahoy::Event.create!(
          name: payload[:name], properties: payload[:properties],
          user_id: payload[:user]&.id, visit: visit, time: Time.current
        )
      end
    ensure
      store.clear
    end

    def self.create_batch_visit(label)
      Ahoy::Visit.create!(
        user_id: Current.user&.id, started_at: Time.current, landing_page: label,
        visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid
      )
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
