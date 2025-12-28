class QuoteDecorator < ApplicationDecorator

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

	def main_image_url
		if main_image&.file&.attached?
			Rails.application.routes.url_helpers.url_for(main_image.file)
		elsif gallery_images.first&.file&.attached?
			Rails.application.routes.url_helpers.url_for(gallery_images.first.file)
		else
			ActionController::Base.helpers.asset_path("theme_default.png")
		end
	end

	def title
		"#{attribution} re #{workshop&.title}"
	end

	def detail(length: nil)
		text = object.quote
		length ? text&.truncate(length) : text
	end
end
