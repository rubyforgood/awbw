class ProjectUserDecorator < ApplicationDecorator

	def detail
		"#{user.full_name}: #{title.presence || position} - #{project.name}"
	end
end
