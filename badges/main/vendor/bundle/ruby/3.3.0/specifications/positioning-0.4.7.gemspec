# -*- encoding: utf-8 -*-
# stub: positioning 0.4.7 ruby lib

Gem::Specification.new do |s|
  s.name = "positioning".freeze
  s.version = "0.4.7".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/brendon/positioning/blob/main/CHANGELOG.md", "funding_uri" => "https://github.com/sponsors/brendon", "homepage_uri" => "https://github.com/brendon/positioning", "source_code_uri" => "https://github.com/brendon/positioning" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Brendon Muir".freeze]
  s.bindir = "exe".freeze
  s.date = "1980-01-02"
  s.email = ["brendon@spike.net.nz".freeze]
  s.homepage = "https://github.com/brendon/positioning".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.0.0".freeze)
  s.rubygems_version = "3.7.1".freeze
  s.summary = "Simple positioning for Active Record models.".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 6.1".freeze])
  s.add_runtime_dependency(%q<activerecord>.freeze, [">= 6.1".freeze])
end
