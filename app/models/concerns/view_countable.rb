module ViewCountable
	extend ActiveSupport::Concern

	def increment_view_count!(session:, request: nil)
		# Rails.logger.warn do
		# 	"[VIEW COUNT] called " \
		# 		"model=#{self.class.name} " \
		# 		"id=#{id} " \
		# 		"path=#{request.fullpath} " \
		# 		"format=#{request.format} " \
		# 		"ua=#{request.user_agent}"
		# end

		if request
			return unless request.request_method.in?(%w[GET HEAD])
			return unless request.format.html? || request.format.turbo_stream?
		end

		session_key = :"viewed_#{self.class.name}_ids"
		session[session_key] ||= []
		return if session[session_key].include?(id)

		increment!(:view_count)
		session[session_key] << id

		# Rails.logger.warn do
		# 	"[VIEW COUNT] incremented id=#{id} new_value=#{view_count}"
		# end
	end


end
