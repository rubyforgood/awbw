# -*- encoding: utf-8 -*-
# stub: trilogy 2.9.0 ruby lib
# stub: ext/trilogy-ruby/extconf.rb

Gem::Specification.new do |s|
  s.name = "trilogy".freeze
  s.version = "2.9.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["GitHub Engineering".freeze]
  s.date = "2024-10-11"
  s.email = "opensource+trilogy@github.com".freeze
  s.extensions = ["ext/trilogy-ruby/extconf.rb".freeze]
  s.files = ["ext/trilogy-ruby/extconf.rb".freeze]
  s.homepage = "https://github.com/trilogy-libraries/trilogy".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.5.11".freeze
  s.summary = "A friendly MySQL-compatible library for Ruby, binding to libtrilogy".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_development_dependency(%q<rake-compiler>.freeze, ["~> 1.0".freeze])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.5".freeze])
end
