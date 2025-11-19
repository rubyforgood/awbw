module UrlSafetyHelper
	def safe_url(url)
		return "#" if url.blank?

		uri = URI.parse(url) rescue nil
		return "#" unless uri

		# allow only http or https
		return uri.to_s if uri.scheme&.match?(/\Ahttps?\z/i)

		"#"
	end
end