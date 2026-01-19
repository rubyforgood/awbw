# Monkey patch to fix Rails 8.2 deprecation warnings in apipie-rails 1.5.0
# ISSUE: The apipie-rails gem uses the old hash argument syntax for routing,
# which is deprecated in Rails 8.1 and will be removed in Rails 8.2:
# DEPRECATION WARNING: get received a hash argument as. Please use a keyword
# instead. Support to hash argument will be removed in Rails 8.2.
#
# SOLUTION: This initializer overrides the apipie routing method to use the new
# keyword argument syntax for Rails route definitions.
#
# OLD SYNTAX (deprecated):
#   get 'path', :to => "controller#action", :format => "json"
#   get(hash_with_path => "controller#action", :as => :name)
#
# NEW SYNTAX (Rails 8+ compatible):
#   get 'path', to: "controller#action", format: "json"
#   get "path", to: "controller#action", as: :name
#
# This patch can be removed once apipie-rails is updated to support Rails 8.2+
# See: https://github.com/Apipie/apipie-rails/issues (check for related issues)
module Apipie
  module Routing
    module MapperExtensions
      def apipie(options = {})
        namespace "apipie", path: Apipie.configuration.doc_base_url do
          get "apipie_checksum", to: "apipies#apipie_checksum", format: "json"
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
