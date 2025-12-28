module ExternallyRedirectable
	extend ActiveSupport::Concern

	def redirect_to_external(url)
		redirect_to url, allow_other_host: true
	end
end
