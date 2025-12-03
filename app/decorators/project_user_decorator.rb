class ProjectUserDecorator < Draper::Decorator
	delegate_all


	def description
		"#{user.full_name}: #{title.presence || position} - #{project.name}"
	end
end
