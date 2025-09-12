# -*- encoding: utf-8 -*-
# stub: ckeditor 4.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "ckeditor".freeze
  s.version = "4.3.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Igor Galeta".freeze]
  s.date = "2018-12-29"
  s.description = "CKEditor is a WYSIWYG editor to be used inside web pages".freeze
  s.email = "galeta.igor@gmail.com".freeze
  s.extra_rdoc_files = ["README.md".freeze]
  s.files = ["README.md".freeze]
  s.homepage = "https://github.com/galetahub/ckeditor".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.6.11".freeze
  s.summary = "Rails gem for easy integration ckeditor in your application".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<terrapin>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<orm_adapter>.freeze, ["~> 0.5.0".freeze])
end
