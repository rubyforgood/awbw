class QuoteDecorator < Draper::Decorator
	delegate_all

	def created_by # TODO - add to model and quote creation
		object.quotable_item_quotes.last&.quotable&.decorate&.created_by
	end

	def quote
		object.quote
	end

	def attribution
		name = speaker_name.presence || "anonymous"

		details = []
		details << "#{age.gsub("years","").gsub("yrs","")} yrs" if age.present?
		details << gender if gender.present?

		if details.any?
			"#{name} (#{details.join(', ')})"
		else
			name
		end
	end

	def title
		"#{speaker_name} re #{workshop&.title}"
	end

	def description
		object.quote
	end
end
