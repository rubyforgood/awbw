class CategoryTypeDecorator < Draper::Decorator
	delegate_all

	def title
		name
	end

	def description
	end
end
