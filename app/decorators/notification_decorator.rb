class NotificationDecorator < ApplicationDecorator

	def title
		"Re #{noticeable_type} ##{noticeable_id}"
	end

	def detail
	end
end
