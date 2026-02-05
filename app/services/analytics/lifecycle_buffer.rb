# app/services/analytics/lifecycle_buffer.rb
module Analytics
  class LifecycleBuffer
    def self.push(event)
      store << event
    end

    def self.flush(controller)
      return if store.empty?

      store.each do |payload|
        controller.ahoy.track(payload[:name], payload[:properties])
      end
    ensure
      store.clear
    end

    def self.store
      Thread.current[:_ahoy_lifecycle_events] ||= []
    end
  end
end
