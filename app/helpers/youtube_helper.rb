module YoutubeHelper
	def youtube_embed_url(url)
		return if url.blank?

		uri = URI.parse(url) rescue nil
		return unless uri

		if uri.host&.include?("youtu.be")
			video_id = uri.path.delete_prefix("/")
		elsif uri.query
			params = Rack::Utils.parse_query(uri.query)
			video_id = params["v"]
		end

		return unless video_id

		"https://www.youtube.com/embed/#{video_id}"
	end
end
