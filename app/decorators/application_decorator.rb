class ApplicationDecorator < Draper::Decorator
	delegate_all

	def link_target
		object.respond_to?(:website_url) && object.website_url.present? ?
			object.website_url :
			default_link_target
	end

	private

	def default_link_target
		h.polymorphic_path(object)
	end
end