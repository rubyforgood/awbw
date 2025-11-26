class FaqDecorator < Draper::Decorator
	delegate_all

	def title
		question
	end

	def description
		answer
	end
end
