module AhoyViewTracking
  extend ActiveSupport::Concern

  def track_view(resource)
    return if already_tracked?(:view, resource)
    ahoy.track "view.#{resource.class.table_name.singularize}", {
      resource_type: resource.class.name,
      resource_id: resource.id,
      resource_title: resource.decorate.title
    }
  end

  def track_print(resource)
    return if already_tracked?(:print, resource)
    ahoy.track "print.#{resource.class.table_name.singularize}", {
      resource_type: resource.class.name,
      resource_id: resource.id,
      resource_title: resource.decorate.title
    }
  end

  def track_download(resource)
    return if already_tracked?(:download, resource)
    ahoy.track "download.#{resource.class.table_name.singularize}", {
      resource_type: resource.class.name,
      resource_id: resource.id,
      resource_title: resource.decorate.title
    }
  end

  private

  def already_tracked?(action, resource)
    # ---- TEST ENVIRONMENT (safe, no session, no ahoy) ----
    if Rails.env.test? && defined?(RSpec)
      request_store[action] ||= Set.new
      return true if request_store[action].include?(resource.id)

      request_store[action] << resource.id
      return false
    end

    # ---- REAL ENVIRONMENT (per visit) ----
    return false unless ahoy&.visit_token

    Ahoy::Event.joins(:visit).where(
      name: "#{action}.#{resource.class.table_name.singularize}",
      ahoy_visits: { visit_token: ahoy.visit_token }
    ).where(
      "ahoy_events.properties ->> '$.resource_id' = ?", resource.id.to_s
    ).exists?
  end

  def request_store
    @ahoy_request_store ||= {}
  end
end
