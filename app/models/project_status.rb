class ProjectStatus < ApplicationRecord
  PROJECT_STATUSES = ['Active', 'Inactive', 'Pending', 'Reinstate', 'Suspended']

  def self.create_defaults
    PROJECT_STATUSES.each do |name|
      ProjectStatus.find_or_create_by(name: name)
    end
  end
end
