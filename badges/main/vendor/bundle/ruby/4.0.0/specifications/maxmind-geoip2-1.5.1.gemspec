# -*- encoding: utf-8 -*-
# stub: maxmind-geoip2 1.5.1 ruby lib

Gem::Specification.new do |s|
  s.name = "maxmind-geoip2".freeze
  s.version = "1.5.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/maxmind/GeoIP2-ruby/issues", "changelog_uri" => "https://github.com/maxmind/GeoIP2-ruby/blob/main/CHANGELOG.md", "documentation_uri" => "https://www.rubydoc.info/gems/maxmind-geoip2", "homepage_uri" => "https://github.com/maxmind/GeoIP2-ruby", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/maxmind/GeoIP2-ruby" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["William Storey".freeze]
  s.date = "1980-01-02"
  s.description = "A gem for interacting with the GeoIP2 webservices and databases. MaxMind provides geolocation data as downloadable databases as well as through a webservice.".freeze
  s.email = "support@maxmind.com".freeze
  s.homepage = "https://github.com/maxmind/GeoIP2-ruby".freeze
  s.licenses = ["Apache-2.0".freeze, "MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.6.9".freeze
  s.summary = "A gem for interacting with the GeoIP2 webservices and databases.".freeze

  s.installed_by_version = "4.0.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<connection_pool>.freeze, [">= 2.2".freeze, "< 4.0".freeze])
  s.add_runtime_dependency(%q<http>.freeze, [">= 4.3".freeze, "< 6.0".freeze])
  s.add_runtime_dependency(%q<maxmind-db>.freeze, ["~> 1.4".freeze])
  s.add_development_dependency(%q<minitest>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop-minitest>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop-performance>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop-rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop-thread_safety>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<webmock>.freeze, [">= 0".freeze])
end
