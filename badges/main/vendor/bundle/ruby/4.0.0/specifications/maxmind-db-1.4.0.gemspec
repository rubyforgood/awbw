# -*- encoding: utf-8 -*-
# stub: maxmind-db 1.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "maxmind-db".freeze
  s.version = "1.4.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/maxmind/MaxMind-DB-Reader-ruby/issues", "changelog_uri" => "https://github.com/maxmind/MaxMind-DB-Reader-ruby/blob/main/CHANGELOG.md", "documentation_uri" => "https://www.rubydoc.info/gems/maxmind-db", "homepage_uri" => "https://github.com/maxmind/MaxMind-DB-Reader-ruby", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/maxmind/MaxMind-DB-Reader-ruby" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["William Storey".freeze]
  s.date = "1980-01-02"
  s.description = "A gem for reading MaxMind DB files. MaxMind DB is a binary file format that stores data indexed by IP address subnets (IPv4 or IPv6).".freeze
  s.email = "support@maxmind.com".freeze
  s.homepage = "https://github.com/maxmind/MaxMind-DB-Reader-ruby".freeze
  s.licenses = ["Apache-2.0".freeze, "MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.6.9".freeze
  s.summary = "A gem for reading MaxMind DB files.".freeze

  s.installed_by_version = "4.0.3".freeze

  s.specification_version = 4

  s.add_development_dependency(%q<minitest>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop-minitest>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop-performance>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop-rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rubocop-thread_safety>.freeze, [">= 0".freeze])
end
