ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# WORKSPACE_PORT gives each parallel workspace its own database, session cookie,
# and host. Under Conductor, fall back to its CONDUCTOR_PORT so a bare
# `bundle exec rspec` or `bin/rails` in a workspace shell can't reach the shared
# default databases. This is the only place the app names Conductor.
ENV["WORKSPACE_PORT"] = ENV["CONDUCTOR_PORT"] if ENV["WORKSPACE_PORT"].to_s.empty? && !ENV["CONDUCTOR_PORT"].to_s.empty?

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
