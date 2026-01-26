class ProjectUserDecorator < ApplicationDecorator
  def detail(length: nil)
    "#{user.full_name}: #{title.presence || position} - #{project.name}"
  end
end
