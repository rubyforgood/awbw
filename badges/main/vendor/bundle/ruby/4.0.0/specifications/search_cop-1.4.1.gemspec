# -*- encoding: utf-8 -*-
# stub: search_cop 1.4.1 ruby lib

Gem::Specification.new do |s|
  s.name = "search_cop".freeze
  s.version = "1.4.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/mrkamel/search_cop/blob/master/CHANGELOG.md", "homepage_uri" => "https://github.com/mrkamel/search_cop", "source_code_uri" => "https://github.com/mrkamel/search_cop" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Benjamin Vetter".freeze]
  s.date = "2025-10-08"
  s.description = "Search engine like fulltext query support for ActiveRecord".freeze
  s.email = ["vetter@flakks.com".freeze]
  s.homepage = "https://github.com/mrkamel/search_cop".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.6.2".freeze
  s.summary = "Easily perform complex search engine like fulltext queries on your ActiveRecord models".freeze

  s.installed_by_version = "4.0.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<treetop>.freeze, [">= 0".freeze])
end
