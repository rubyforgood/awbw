module AhoyViewTracking
  extend ActiveSupport::Concern

  def track_view(resource)
    ahoy.track "#{resource.class.name} View", {
      resource_type: resource.class.name,
      resource_id: resource.id,
      resource_title: (resource.try(:title) || resource.try(:name) || resource.try(:full_name))
    }
  end
end
