module AhoyViewTracking
  extend ActiveSupport::Concern

  def track_view(resource)
    ahoy.track "view.#{resource.class.table_name.singularize}", {
      resource_type: resource.class.name,
      resource_id: resource.id,
      resource_title: resource_title_for(resource)
    }
  end

  def track_print(resource)
    ahoy.track "print.#{resource.class.table_name.singularize}", {
      resource_type: resource.class.name,
      resource_id: resource.id,
      resource_title: resource_title_for(resource)
    }
  end

  def track_download(resource)
    ahoy.track "download.#{resource.class.table_name.singularize}", {
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
