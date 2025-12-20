class CategoryTypeDecorator < ApplicationDecorator

	def title
		name.titleize
	end

	def detail
	end
end
