class CategoryTypeDecorator < Draper::Decorator
	delegate_all

	def title
		name.titleize
	end

	def description
	end
end
