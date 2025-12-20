module Linkable
	extend ActiveSupport::Concern

	def link_target
		website_url.presence || default_link_target
	end

	private

	def default_link_target
		Rails.application.routes.url_helpers.polymorphic_path(self)
	end
end
