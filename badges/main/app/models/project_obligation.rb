class ProjectObligation < ApplicationRecord

  def self.create_defaults
    ['Current Grant Funded', 'Previous Grant Funded',
     'Voluntary Reporting', 'Intermittent Reporting',
     'Active Non-Reporting'].each do |name|
      ProjectObligation.find_or_create_by(name: name)
     end
  end
end
