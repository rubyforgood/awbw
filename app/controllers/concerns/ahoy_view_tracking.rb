module AhoyViewTracking
  extend ActiveSupport::Concern

  def track_view(resource)
    return if already_tracked?(:view, resource)
    ahoy.track "view.#{resource.class.table_name.singularize}", {
      resource_type: resource.class.name,
      resource_id: resource.id,
      resource_title: resource.decorate.title
    }
    mark_as_tracked(:view, resource)
  end

  def track_print(resource)
    return if already_tracked?(:print, resource)
    ahoy.track "print.#{resource.class.table_name.singularize}", {
      resource_type: resource.class.name,
      resource_id: resource.id,
      resource_title: resource.decorate.title
    }
    mark_as_tracked(:print, resource)
  end

  def track_download(resource)
    return if already_tracked?(:download, resource)
    ahoy.track "download.#{resource.class.table_name.singularize}", {
      resource_type: resource.class.name,
      resource_id: resource.id,
      resource_title: resource.decorate.title
    }
    mark_as_tracked(:download, resource)
  end

  private

  def already_tracked?(action, resource)
    session_key = :"ahoy_tracked_#{action}_#{resource.class.name}_ids"
    session[session_key] ||= []
    session[session_key].include?(resource.id)
  end

  def mark_as_tracked(action, resource)
    session_key = :"ahoy_tracked_#{action}_#{resource.class.name}_ids"
    session[session_key] ||= []
    session[session_key] << resource.id
    ahoy.track "#{resource.class.name} View", {
      resource_type: resource.class.name,
      resource_id: resource.id,
      resource_title: resource_title_for(resource)
    }
  end

  private

  def resource_title_for(resource)
    case
    when resource.respond_to?(:title)
      resource.title
    when resource.respond_to?(:name)
      resource.name
    when resource.respond_to?(:full_name)
      resource.full_name
    else
      nil
    end
  end
end
