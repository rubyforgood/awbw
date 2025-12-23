class ApplicationDecorator < Draper::Decorator
	delegate_all

	def object_link_target
		if object.respond_to?(:link_target)
			object.link_target
		else
			object_default_link_target
		end
	end

	private

	def object_default_link_target
		h.polymorphic_path(object)
	end
end