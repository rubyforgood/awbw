class ProjectStatus < ApplicationRecord

  def self.create_defaults
    ['Active', 'Inactive', 'Pending', 'Reinstate', 'Suspended'].each do |name|
      ProjectStatus.find_or_create_by(name: name)
    end
  end
end
