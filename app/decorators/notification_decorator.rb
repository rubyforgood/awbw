class NotificationDecorator < Draper::Decorator
	delegate_all

	def title
		"Re #{noticeable_type} ##{noticeable_id}"
	end

	def description
	end
end
