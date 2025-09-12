# -*- encoding: utf-8 -*-
# stub: remotipart 1.4.4 ruby lib

Gem::Specification.new do |s|
  s.name = "remotipart".freeze
  s.version = "1.4.4".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Greg Leppert".freeze, "Steve Schwartz".freeze]
  s.date = "2019-12-29"
  s.description = "Remotipart is a Ruby on Rails gem enabling remote multipart forms (AJAX style file uploads) with jquery-rails.\n    This gem augments the native Rails 3 jQuery-UJS remote form function enabling asynchronous file uploads with little to no modification to your application.\n    ".freeze
  s.email = ["greg@formasfunction.com".freeze, "steve@alfajango.com".freeze]
  s.extra_rdoc_files = ["LICENSE".freeze, "README.rdoc".freeze]
  s.files = ["LICENSE".freeze, "README.rdoc".freeze]
  s.homepage = "http://opensource.alfajango.com/remotipart/".freeze
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Remotipart is a Ruby on Rails gem enabling remote multipart forms (AJAX style file uploads) with jquery-rails.".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<jeweler>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<appraisal>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<jquery-rails>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<sqlite3>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<paperclip>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<remotipart>.freeze, [">= 0".freeze])
end
