# -*- encoding: utf-8 -*-
# stub: pry-coolline 0.2.6 ruby lib

Gem::Specification.new do |s|
  s.name = "pry-coolline".freeze
  s.version = "0.2.6".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["John Mair (banisterfiend)".freeze]
  s.date = "2021-12-31"
  s.description = "Live syntax-highlighting for the Pry REPL".freeze
  s.email = "jrmair@gmail.com".freeze
  s.homepage = "https://github.com/pry/pry-coolline".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2".freeze)
  s.rubygems_version = "3.2.32".freeze
  s.summary = "Live syntax-highlighting for the Pry REPL".freeze

  s.installed_by_version = "4.0.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<coolline>.freeze, ["~> 0.5".freeze])
  s.add_runtime_dependency(%q<pry>.freeze, ["~> 0.13".freeze])
  s.add_development_dependency(%q<riot>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rake>.freeze, ["~> 10.0".freeze])
end
