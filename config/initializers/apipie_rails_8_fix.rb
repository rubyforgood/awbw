# Monkey patch to fix Rails 8.2 deprecation warnings in apipie-rails
# This overrides the routing method to use keyword arguments instead of hash arguments
# Can be removed once apipie-rails is updated to support Rails 8.2

module Apipie
  module Routing
    module MapperExtensions
      def apipie(options = {})
        namespace "apipie", path: Apipie.configuration.doc_base_url do
          get 'apipie_checksum', to: "apipies#apipie_checksum", format: "json"
          constraints(version: %r{[^/]+}, resource: %r{[^/]+}, method: %r{[^/]+}) do
            # Convert hash argument to keyword arguments for Rails 8.2 compatibility
            route_options = options.reverse_merge(to: "apipies#index", as: :apipie)
            get "(:version)/(:resource)/(:method)", **route_options
          end
        end
      end
    end
  end
end
