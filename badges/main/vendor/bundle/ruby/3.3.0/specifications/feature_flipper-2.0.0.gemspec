# -*- encoding: utf-8 -*-
# stub: feature_flipper 2.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "feature_flipper".freeze
  s.version = "2.0.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Florian Munz".freeze]
  s.date = "2017-05-09"
  s.description = "FeatureFlipper is a simple library that allows you to restrict certain blocks\nof code to certain environments. This is mainly useful in projects where\nyou deploy your application from HEAD and don't use branches.\n".freeze
  s.email = "surf@theflow.de".freeze
  s.homepage = "http://github.com/theflow/feature_flipper".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.0.14".freeze
  s.summary = "FeatureFlipper helps you flipping features".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.0".freeze])
end
