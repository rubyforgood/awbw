class Ahoy::Store < Ahoy::DatabaseStore
end

# set to true for JavaScript tracking
Ahoy.api = true

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = true

# customize Ahoy::Event to extract resource dimensions from properties
Ahoy::Event.class_eval do
	before_validation :extract_resource_dimensions

	def extract_resource_dimensions
		return unless properties

		self.resource_type ||= properties["resource_type"]
		self.resource_id   ||= properties["resource_id"]
	end
end