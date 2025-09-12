# -*- encoding: utf-8 -*-
# stub: devise 4.7.3 ruby lib

Gem::Specification.new do |s|
  s.name = "devise".freeze
  s.version = "4.7.3".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jos\u00E9 Valim".freeze, "Carlos Ant\u00F4nio".freeze]
  s.date = "2020-09-21"
  s.description = "Flexible authentication solution for Rails with Warden".freeze
  s.email = "heartcombo@googlegroups.com".freeze
  s.homepage = "https://github.com/heartcombo/devise".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.1.0".freeze)
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Flexible authentication solution for Rails with Warden".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<warden>.freeze, ["~> 1.2.3".freeze])
  s.add_runtime_dependency(%q<orm_adapter>.freeze, ["~> 0.1".freeze])
  s.add_runtime_dependency(%q<bcrypt>.freeze, ["~> 3.0".freeze])
  s.add_runtime_dependency(%q<railties>.freeze, [">= 4.1.0".freeze])
  s.add_runtime_dependency(%q<responders>.freeze, [">= 0".freeze])
end
