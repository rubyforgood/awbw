class Ahoy::Store < Ahoy::DatabaseStore
end

# set to true for JavaScript tracking
Ahoy.api = true

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = true

# customize Ahoy::Event to extract resource dimensions from properties
Rails.application.config.to_prepare do
  Ahoy::Event.class_eval do
    before_validation :extract_resource_dimensions, on: :create

    def extract_resource_dimensions
      props =
        case properties
        when String
          JSON.parse(properties) rescue {}
        when Hash
          properties
        else
          {}
        end

      self.resource_type ||= props["resource_type"]
      self.resource_id   ||= props["resource_id"]&.to_i
    end
  end
end
