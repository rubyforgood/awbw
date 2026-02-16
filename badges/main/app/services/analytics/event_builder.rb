# app/services/analytics/event_builder.rb
module Analytics
  class EventBuilder
    def self.lifecycle(action, resource, user: nil)
      {
        name: "#{action}.#{resource.class.table_name.singularize}",
        properties: {
          resource_type: resource.class.name,
          resource_id: resource.id,
          resource_title: safe_title(resource)
        },
        user: user
      }
    end

    def self.safe_title(resource)
      if resource.is_a?(Asset) && resource.file.attached?
        return resource.file.filename.to_s
      end

      resource.decorate.title
    rescue
      resource.try(:title) || resource.try(:name) || resource.id
    end
  end
end
