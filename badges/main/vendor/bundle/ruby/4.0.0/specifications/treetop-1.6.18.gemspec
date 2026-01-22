# -*- encoding: utf-8 -*-
# stub: treetop 1.6.18 ruby lib

Gem::Specification.new do |s|
  s.name = "treetop".freeze
  s.version = "1.6.18".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Nathan Sobo".freeze, "Clifford Heath".freeze]
  s.date = "2025-11-13"
  s.description = "A Parsing Expression Grammar (PEG) Parser generator DSL for Ruby".freeze
  s.email = "cliffordheath@gmail.com".freeze
  s.executables = ["tt".freeze]
  s.extra_rdoc_files = ["LICENSE".freeze, "README.md".freeze]
  s.files = ["LICENSE".freeze, "README.md".freeze, "bin/tt".freeze]
  s.homepage = "https://github.com/cjheath/treetop".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.6.9".freeze
  s.summary = "A Ruby-based text parsing and interpretation DSL".freeze

  s.installed_by_version = "4.0.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<polyglot>.freeze, ["~> 0.3".freeze])
  s.add_development_dependency(%q<i18n>.freeze, ["~> 1.0".freeze])
  s.add_development_dependency(%q<rr>.freeze, ["~> 3.0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3".freeze])
  s.add_development_dependency(%q<rake>.freeze, ["~> 11".freeze])
end
