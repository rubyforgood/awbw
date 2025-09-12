# -*- encoding: utf-8 -*-
# stub: terrapin 0.6.0 ruby lib

Gem::Specification.new do |s|
  s.name = "terrapin".freeze
  s.version = "0.6.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jon Yurek".freeze]
  s.date = "2018-02-02"
  s.description = "Run shell commands safely, even with user-supplied values".freeze
  s.email = "jyurek@thoughtbot.com".freeze
  s.homepage = "https://github.com/thoughtbot/terrapin".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.6.14".freeze
  s.summary = "Run shell commands safely, even with user-supplied values".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<climate_control>.freeze, [">= 0.0.3".freeze, "< 1.0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<bourne>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<mocha>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<activesupport>.freeze, [">= 3.0.0".freeze, "< 5.0".freeze])
  s.add_development_dependency(%q<pry>.freeze, [">= 0".freeze])
end
