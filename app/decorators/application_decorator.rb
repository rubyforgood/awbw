class ApplicationDecorator < Draper::Decorator
	delegate_all

	def link_target
		h.polymorphic_path(object)
	end

	def external_link?
		false
	end

end
