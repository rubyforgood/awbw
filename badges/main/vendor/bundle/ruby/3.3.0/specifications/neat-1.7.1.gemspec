# -*- encoding: utf-8 -*-
# stub: neat 1.7.1 ruby lib

Gem::Specification.new do |s|
  s.name = "neat".freeze
  s.version = "1.7.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Joel Oliveira".freeze, "Kyle Fiedler".freeze, "Reda Lemeden".freeze]
  s.date = "2015-01-02"
  s.description = "Neat is a fluid grid framework built with Bourbon with the aim of being easy\nenough to use out of the box and flexible enough to customize down the road.\n".freeze
  s.email = "design+bourbon@thoughtbot.com".freeze
  s.executables = ["neat".freeze]
  s.files = ["bin/neat".freeze]
  s.homepage = "http://neat.bourbon.io".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.2.2".freeze
  s.summary = "A lightweight, semantic grid framework built with Bourbon".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<sass>.freeze, [">= 3.3".freeze])
  s.add_runtime_dependency(%q<bourbon>.freeze, [">= 4.0".freeze])
  s.add_development_dependency(%q<aruba>.freeze, ["~> 0.5.0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<css_parser>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rdoc>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rb-fsevent>.freeze, ["~> 0.9.1".freeze])
  s.add_development_dependency(%q<scss-lint>.freeze, ["~> 0.29.0".freeze])
end
