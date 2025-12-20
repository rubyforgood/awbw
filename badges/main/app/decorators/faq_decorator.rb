class FaqDecorator < ApplicationDecorator

	def title
		question
	end

	def detail
		answer
	end
end
