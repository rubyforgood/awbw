module Linkable
	extend ActiveSupport::Concern

	included do
		# Override this in each model with something like:
		# def internal_url
		#   Rails.application.routes.url_helpers.story_path(self)
		# end
	end

	def link_target
		if external_link?
			normalized_url(external_url)
		else
			default_link_target
		end
	end

	def external_link?
		external_url.present? && valid_external_url?(external_url)
	end

	# Models must implement this method.
	def external_url
		raise NotImplementedError, "Models including Linkable must define #external_url"
	end

	private

	def valid_external_url?(value)
		return false if value.blank?

		# Only normalize *naked domains*, not scheme-bearing strings
		if value =~ /\A[\w.-]+\.[a-z]{2,}/i
			value = "https://#{value}" unless value =~ /\Ahttps?:\/\//i
		end

		uri = URI.parse(value)
		uri.host.present? && %w[http https].include?(uri.scheme&.downcase)
	rescue URI::InvalidURIError
		false
	end

	def default_link_target
		Rails.application.routes.url_helpers.polymorphic_path(self)
	end

	def normalized_url(value)
		return "" if value.blank?
		value =~ /\Ahttp(s)?:\/\// ? value : "https://#{value}"
	end
end
