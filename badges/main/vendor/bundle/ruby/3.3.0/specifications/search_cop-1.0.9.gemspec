# -*- encoding: utf-8 -*-
# stub: search_cop 1.0.9 ruby lib

Gem::Specification.new do |s|
  s.name = "search_cop".freeze
  s.version = "1.0.9".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Benjamin Vetter".freeze]
  s.date = "2017-07-12"
  s.description = "Search engine like fulltext query support for ActiveRecord".freeze
  s.email = ["vetter@flakks.com".freeze]
  s.homepage = "https://github.com/mrkamel/search_cop".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.2.2".freeze
  s.summary = "Easily perform complex search engine like fulltext queries on your ActiveRecord models".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<treetop>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<activerecord>.freeze, [">= 3.0.0".freeze])
  s.add_development_dependency(%q<factory_girl>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<appraisal>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<minitest>.freeze, [">= 0".freeze])
end
